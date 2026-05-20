//
//  StationNowPlayingService.swift
//  SwiftRadio
//

import Foundation

extension Notification.Name {
    /// Posted when JSON from `nowPlayingURL` is fetched and display metadata may have changed.
    static let externalNowPlayingMetadataDidUpdate = Notification.Name("externalNowPlayingMetadataDidUpdate")
}

/// Polls optional per-station `nowPlayingURL` so title/artist can come from your API instead of stream ICY metadata.
/// Thread-safe for reads from `RadioStation` computed properties (may run off the main actor).
final class StationNowPlayingService {

    static let shared = StationNowPlayingService()

    private static let pollInterval: TimeInterval = 15

    private let stateLock = NSLock()
    private var pollTimer: Timer?
    /// Station identity for metadata; must not depend on which tier URL is playing.
    private var boundStation: RadioStation?
    private var overrideTitle: String?
    private var overrideArtist: String?

    private init() {}

    /// Must be called from the main thread / main actor (stations manager uses `Task { @MainActor in … }`).
    func bind(to station: RadioStation?) {
        assert(Thread.isMainThread)
        pollTimer?.invalidate()
        pollTimer = nil

        stateLock.lock()
        boundStation = station
        overrideTitle = nil
        overrideArtist = nil
        stateLock.unlock()

        guard !PodcastPlaybackService.shared.isPodcastMode else {
            postUpdate()
            return
        }

        guard let station else {
            postUpdate()
            return
        }

        guard let raw = station.nowPlayingURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty,
              let url = URL(string: raw),
              url.scheme == "http" || url.scheme == "https" else {
            postUpdate()
            return
        }

        Task { await fetchAndApply(url: url, isInitial: true) }

        pollTimer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { await self.fetchAndApply(url: url, isInitial: false) }
        }
        if let timer = pollTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    /// `true` after a successful fetch produced at least one non-empty field for the bound station.
    func hasExternalMetadata(for station: RadioStation) -> Bool {
        stateLock.lock()
        let bound = boundStation
        let title = overrideTitle
        let artist = overrideArtist
        stateLock.unlock()

        guard let bound, bound == station else { return false }
        let t = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let a = artist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !t.isEmpty || !a.isEmpty
    }

    func preferredTitle(for station: RadioStation) -> String? {
        stateLock.lock()
        let bound = boundStation
        let title = overrideTitle
        stateLock.unlock()

        guard let bound, bound == station else { return nil }
        let t = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return t.isEmpty ? nil : t
    }

    func preferredArtist(for station: RadioStation) -> String? {
        stateLock.lock()
        let bound = boundStation
        let artist = overrideArtist
        stateLock.unlock()

        guard let bound, bound == station else { return nil }
        let a = artist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return a.isEmpty ? nil : a
    }

    private func fetchAndApply(url: URL, isInitial: Bool) async {
        guard !PodcastPlaybackService.shared.isPodcastMode else { return }
        stateLock.lock()
        let bound = boundStation
        stateLock.unlock()
        guard let station = bound else { return }
        guard StationsManager.shared.currentStation == station else { return }

        do {
            let (title, artist) = try await NetworkService.fetchExternalNowPlaying(from: url)
            stateLock.lock()
            let stillBound = boundStation
            stateLock.unlock()
            guard stillBound == station, StationsManager.shared.currentStation == station else { return }
            await MainActor.run {
                stateLock.lock()
                overrideTitle = title
                overrideArtist = artist
                stateLock.unlock()
                if Config.debugLog, isInitial {
                    print("nowPlayingURL OK: title=\(String(describing: title)) artist=\(String(describing: artist))")
                }
            }
        } catch {
            // Keep the last successfully-fetched title/artist rather than clearing to nil.
            // Clearing on error causes the player screen to go blank when a bitrate switch
            // clears ICY metadata at the same time the poll happens to fail — the external
            // data is independent of which stream tier is active and should persist through
            // transient API outages. Data is only reset when bind(to:) is called (station change).
            if Config.debugLog {
                await MainActor.run {
                    print("nowPlayingURL fetch failed: \(error.localizedDescription)")
                }
            }
        }
        postUpdate()
    }

    private func postUpdate() {
        if Thread.isMainThread {
            NotificationCenter.default.post(name: .externalNowPlayingMetadataDidUpdate, object: nil)
        } else {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .externalNowPlayingMetadataDidUpdate, object: nil)
            }
        }
    }
}
