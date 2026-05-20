//
//  PodcastsStore.swift
//  SwiftRadio
//
//  Created by RadioCopilot on 2026-04-29.
//

import Foundation
import FRadioPlayer

extension Notification.Name {
    static let podcastPlaybackDidChange = Notification.Name("podcastPlaybackDidChange")
    static let podcastStoreArtworkDidUpdate = Notification.Name("podcastStoreArtworkDidUpdate")
}

struct PodcastPlaybackItem: Equatable {
    let audioURL: URL
    let title: String
    let artist: String
    let artworkURL: URL?
    let sourceURL: URL?
}

final class PodcastPlaybackService {
    static let shared = PodcastPlaybackService()

    private let player = FRadioPlayer.shared

    private(set) var isPodcastMode: Bool = false
    private(set) var currentEpisode: PodcastPlaybackItem?

    private init() {}

    func playEpisode(
        audioURL: URL,
        title: String,
        artist: String,
        artworkURL: URL?,
        sourceURL: URL?
    ) {
        currentEpisode = PodcastPlaybackItem(
            audioURL: audioURL,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Podcast Episode" : title,
            artist: artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Podcast" : artist,
            artworkURL: artworkURL,
            sourceURL: sourceURL
        )
        isPodcastMode = true
        postDidChange()

        if player.radioURL?.absoluteString != audioURL.absoluteString {
            player.radioURL = audioURL
        }
        DispatchQueue.main.async {
            StationNowPlayingService.shared.bind(to: nil)
        }
        player.play()
    }

    func exitPodcastMode() {
        guard isPodcastMode || currentEpisode != nil else { return }
        isPodcastMode = false
        currentEpisode = nil
        postDidChange()
        DispatchQueue.main.async {
            StationNowPlayingService.shared.bind(to: StationsManager.shared.currentStation)
        }
    }

    private func postDidChange() {
        if Thread.isMainThread {
            NotificationCenter.default.post(name: .podcastPlaybackDidChange, object: nil)
        } else {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .podcastPlaybackDidChange, object: nil)
            }
        }
    }
}

final class PodcastsStore {
    static let shared = PodcastsStore()

    let podcasts: [Podcast]

    /// Cached channel artwork URLs keyed by podcast ID.
    private var channelArtworkURLs: [String: URL] = [:]

    private init() {
        podcasts = Config.Podcasts.feeds
        // Pre-populate from any static artworkURL in Config.
        for podcast in podcasts {
            if let url = podcast.artworkURL {
                channelArtworkURLs[podcast.id] = url
            }
        }
    }

    func cachedArtworkURL(for podcastID: String) -> URL? {
        channelArtworkURLs[podcastID]
    }

    func updateChannelArtwork(_ artworkURL: URL?, for podcastID: String) {
        guard let artworkURL else { return }
        guard channelArtworkURLs[podcastID] != artworkURL else { return }
        channelArtworkURLs[podcastID] = artworkURL
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .podcastStoreArtworkDidUpdate, object: podcastID)
        }
    }

    /// Fetches channel artwork for podcasts that don't yet have a cached URL.
    func prefetchChannelArtworkIfNeeded(for podcasts: [Podcast]) {
        for podcast in podcasts {
            guard channelArtworkURLs[podcast.id] == nil else { continue }
            Task {
                guard let result = try? await PodcastRSSService.fetchEpisodes(for: podcast) else { return }
                await MainActor.run {
                    self.updateChannelArtwork(result.channelArtworkURL, for: podcast.id)
                }
            }
        }
    }
}

final class ListenedEpisodesStore {
    static let shared = ListenedEpisodesStore()

    private let defaults = UserDefaults.standard
    private let key = "listenedEpisodeIDs"

    private init() {}

    private var listenedIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: key) ?? []) }
        set { defaults.set(Array(newValue), forKey: key) }
    }

    func isListened(_ episodeID: String) -> Bool {
        listenedIDs.contains(episodeID)
    }

    func markListened(_ episodeID: String) {
        var ids = listenedIDs
        ids.insert(episodeID)
        listenedIDs = ids
    }
}
