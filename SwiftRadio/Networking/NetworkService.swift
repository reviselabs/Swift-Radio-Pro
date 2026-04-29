//
//  NetworkService.swift
//  SwiftRadio
//
//  Created by Fethi El Hassasna on 2025-01-31.
//  Copyright © 2025 matthewfecher.com. All rights reserved.
//

import UIKit

// MARK: - Image session (bounded cache; avoids unbounded URLCache.shared growth from artwork / logos)

private enum ImageNetwork {
    /// Isolated HTTP cache for image GETs (station logos, stream artwork). Caps disk use that previously could reach gigabytes via `URLCache.shared`.
    static let urlCache: URLCache = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = caches.appendingPathComponent("SwiftRadioImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return URLCache(
            memoryCapacity: 12 * 1024 * 1024,
            diskCapacity: 36 * 1024 * 1024,
            directory: dir
        )
    }()

    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = urlCache
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 45
        config.httpMaximumConnectionsPerHost = 4
        return URLSession(configuration: config)
    }()
}

// MARK: - Error

enum NetworkError: Error {
    case urlNotValid, dataNotValid, dataNotFound, fileNotFound, httpResponseNotValid
}

// MARK: - GitHub Models

struct Contributor: Decodable {
    let login: String
    let avatarURL: URL
    let htmlURL: URL
    let contributions: Int

    enum CodingKeys: String, CodingKey {
        case login
        case avatarURL = "avatar_url"
        case htmlURL = "html_url"
        case contributions
    }
}

struct GitHubRepo: Decodable {
    let name: String
    let description: String?
}

// MARK: - NetworkService

struct NetworkService {

    // MARK: - Stations

    static func fetchStations() async throws -> [RadioStation] {
        let data: Data

        if Config.useLocalStations {
            guard let fileURL = Bundle.main.url(forResource: "stations", withExtension: "json") else {
                if Config.debugLog { print("The local JSON file could not be found") }
                throw NetworkError.fileNotFound
            }
            data = try Data(contentsOf: fileURL, options: .uncached)
        } else {
            guard let url = URL(string: Config.stationsURL) else {
                if Config.debugLog { print("stationsURL not a valid URL") }
                throw NetworkError.urlNotValid
            }

            let config = URLSessionConfiguration.default
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            let session = URLSession(configuration: config)

            let (responseData, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse, 200...299 ~= httpResponse.statusCode else {
                if Config.debugLog { print("API: HTTP status code has unexpected value") }
                throw NetworkError.httpResponseNotValid
            }

            data = responseData
        }

        if Config.debugLog { print("Stations JSON Found") }

        let jsonDictionary = try JSONDecoder().decode([String: [RadioStation]].self, from: data)

        guard let stations = jsonDictionary["station"] else {
            throw NetworkError.dataNotValid
        }

        return stations
    }

    // MARK: - Images

    /// Fetches and decodes an image with a bounded pixel size. Uses a dedicated URLSession + URLCache so disk does not grow without limit.
    static func fetchImage(from url: URL, maxPixelSize: CGFloat = 1080) async -> UIImage? {
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad

        do {
            let (data, response) = try await ImageNetwork.session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  200...299 ~= httpResponse.statusCode,
                  !data.isEmpty else {
                return nil
            }
            return UIImage.swr_decodedImage(from: data, maxPixelSize: maxPixelSize)
        } catch {
            return nil
        }
    }

    // MARK: - GitHub API

    static func fetchContributors(owner: String, repo: String) async throws -> [Contributor] {
        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/contributors") else {
            throw NetworkError.urlNotValid
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw NetworkError.httpResponseNotValid
        }

        return try JSONDecoder().decode([Contributor].self, from: data)
    }

    static func fetchRepository(owner: String, repo: String) async throws -> GitHubRepo {
        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)") else {
            throw NetworkError.urlNotValid
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw NetworkError.httpResponseNotValid
        }

        return try JSONDecoder().decode(GitHubRepo.self, from: data)
    }

    // MARK: - External now playing (stations.json `nowPlayingURL`)

    static func fetchExternalNowPlaying(from url: URL) async throws -> (title: String?, artist: String?) {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 12
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200...299 ~= http.statusCode else {
            throw NetworkError.httpResponseNotValid
        }
        return parseNowPlayingJSON(data)
    }

    /// Best-effort parsing for common JSON shapes (flat keys, AzuraCast `now_playing.song`, nested `data`, arrays of one object, etc.).
    static func parseNowPlayingJSON(_ data: Data) -> (title: String?, artist: String?) {
        guard let obj = try? JSONSerialization.jsonObject(with: data) else { return (nil, nil) }
        if let dict = obj as? [String: Any] {
            return extractTitleArtist(from: dict, depth: 0)
        }
        if let arr = obj as? [[String: Any]], let first = arr.first {
            return extractTitleArtist(from: first, depth: 0)
        }
        return (nil, nil)
    }

    private static func extractTitleArtist(from dict: [String: Any], depth: Int) -> (String?, String?) {
        guard depth < 8 else { return (nil, nil) }

        let directTitle = pickString(dict, keys: ["title", "song", "track", "TrackTitle", "track_title", "trackname", "TrackName"])
        let directArtist = pickString(dict, keys: ["artist", "artistName", "Artist", "artist_name", "performer", "albumArtist", "AlbumArtist"])

        if directTitle != nil || directArtist != nil {
            return (directTitle, directArtist)
        }

        for nestedKey in ["now_playing", "nowPlaying", "data", "result", "current", "np", "metadata", "live", "on_air"] {
            if let nested = dict[nestedKey] as? [String: Any] {
                let found = extractTitleArtist(from: nested, depth: depth + 1)
                if found.0 != nil || found.1 != nil { return found }
            }
        }

        if let song = dict["song"] as? [String: Any] {
            let t = pickString(song, keys: ["title", "track", "text", "name", "song"])
            let a = pickString(song, keys: ["artist", "artistName", "Artist"])
            if t != nil || a != nil { return (t, a) }
        }

        return (nil, nil)
    }

    private static func pickString(_ dict: [String: Any], keys: [String]) -> String? {
        for k in keys {
            if let v = dict[k] as? String {
                let t = v.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { return t }
            }
            if let num = dict[k] as? NSNumber {
                let t = num.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { return t }
            }
        }
        return nil
    }
}
