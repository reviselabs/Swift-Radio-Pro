//
//  RadioStation.swift
//  Swift Radio
//
//  Created by Matthew Fecher on 7/4/15.
//  Copyright (c) 2015 MatthewFecher.com. All rights reserved.
//

import UIKit
import FRadioPlayer

// Radio Station

struct RadioStation: Codable {

    var name: String
    var website: String?
    /// Default / Auto quality stream (required).
    var streamURL: String
    /// Optional tier URLs — same keys as in `stations.json`: `streamURLlow`, `streamURLmid`, `streamURLhigh`.
    /// When a tier is omitted or empty, `streamURL` is used for that setting.
    var streamURLlow: String?
    var streamURLmid: String?
    var streamURLhigh: String?
    /// Optional display strings for the player (e.g. `320 kbps` or `320 Kbps`) when Low / Mid / High is selected.
    var bitrateLabelLow: String?
    var bitrateLabelMid: String?
    var bitrateLabelHigh: String?
    /// Optional JSON API for current track (HTTP/S). Used for title/artist regardless of active stream quality URL.
    var nowPlayingURL: String?
    var imageURL: String
    var desc: String
    var longDesc: String

    init(
        name: String,
        website: String? = nil,
        streamURL: String,
        streamURLlow: String? = nil,
        streamURLmid: String? = nil,
        streamURLhigh: String? = nil,
        bitrateLabelLow: String? = nil,
        bitrateLabelMid: String? = nil,
        bitrateLabelHigh: String? = nil,
        nowPlayingURL: String? = nil,
        imageURL: String,
        desc: String,
        longDesc: String = ""
    ) {
        self.name = name
        self.website = website
        self.streamURL = streamURL
        self.streamURLlow = streamURLlow
        self.streamURLmid = streamURLmid
        self.streamURLhigh = streamURLhigh
        self.bitrateLabelLow = bitrateLabelLow
        self.bitrateLabelMid = bitrateLabelMid
        self.bitrateLabelHigh = bitrateLabelHigh
        self.nowPlayingURL = nowPlayingURL
        self.imageURL = imageURL
        self.desc = desc
        self.longDesc = longDesc
    }
}

extension RadioStation {
    var hasValidWebsite: Bool {
        guard let websiteString = website,
              !websiteString.isEmpty,
              let url = URL(string: websiteString),
              url.scheme?.hasPrefix("http") == true else {
            return false
        }
        return true
    }
    
    var shoutout: String {
        "I'm listening to \(name) via \(Bundle.main.appName) app"
    }

    /// Main Starter FM stream only (bundled weekly show grid + on-air row). Other Starter-branded stations are excluded.
    var showsStarterFMShowSchedule: Bool {
        name == "Starter FM"
    }
}

extension RadioStation: Equatable {
    
    static func == (lhs: RadioStation, rhs: RadioStation) -> Bool {
        lhs.name == rhs.name
            && lhs.streamURL == rhs.streamURL
            && lhs.streamURLlow == rhs.streamURLlow
            && lhs.streamURLmid == rhs.streamURLmid
            && lhs.streamURLhigh == rhs.streamURLhigh
            && lhs.bitrateLabelLow == rhs.bitrateLabelLow
            && lhs.bitrateLabelMid == rhs.bitrateLabelMid
            && lhs.bitrateLabelHigh == rhs.bitrateLabelHigh
            && lhs.nowPlayingURL == rhs.nowPlayingURL
            && lhs.imageURL == rhs.imageURL
            && lhs.desc == rhs.desc
            && lhs.longDesc == rhs.longDesc
    }
}

extension RadioStation {

    func resolvedStreamURL(for mode: StreamQualityMode) -> String {
        func nonEmpty(_ s: String?) -> String? {
            guard let s = s, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return s
        }

        switch mode {
        case .auto:
            return streamURL
        case .low:
            return nonEmpty(streamURLlow) ?? streamURL
        case .medium:
            return nonEmpty(streamURLmid) ?? streamURL
        case .high:
            return nonEmpty(streamURLhigh) ?? streamURL
        }
    }

    func bitrateLabel(for mode: StreamQualityMode) -> String? {
        func cleaned(_ s: String?) -> String? {
            guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
            return s
        }
        switch mode {
        case .auto:
            return nil
        case .low:
            return cleaned(bitrateLabelLow)
        case .medium:
            return cleaned(bitrateLabelMid)
        case .high:
            return cleaned(bitrateLabelHigh)
        }
    }
}

extension RadioStation {
    func getImage(completion: @escaping (_ image: UIImage) -> Void) {
        if imageURL.contains("http"), let url = URL(string: imageURL) {
            Task {
                let image = await NetworkService.fetchImage(from: url)
                await MainActor.run { completion(image ?? UIImage(named: "stationImage")!) }
            }
        } else {
            completion(UIImage(named: imageURL) ?? UIImage(named: "stationImage")!)
        }
    }
}

extension RadioStation {

    var trackName: String {
        if let t = StationNowPlayingService.shared.preferredTitle(for: self) { return t }
        return FRadioPlayer.shared.currentMetadata?.trackName ?? name
    }

    var artistName: String {
        if let a = StationNowPlayingService.shared.preferredArtist(for: self) { return a }
        return FRadioPlayer.shared.currentMetadata?.artistName ?? desc
    }

    var musicSearchURL: URL? {
        let hasStreamTitle = FRadioPlayer.shared.currentMetadata?.trackName != nil
        let hasExternal = nowPlayingURL != nil && StationNowPlayingService.shared.hasExternalMetadata(for: self)
        guard hasStreamTitle || hasExternal else { return nil }
        guard let encodedSongName = trackName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedArtistName = artistName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        let musicSearchURLString = "https://music.apple.com/search?term=\(encodedSongName)+\(encodedArtistName)".replacingOccurrences(of: "%2B", with: "%20")
        return URL(string: musicSearchURLString)
    }
}
