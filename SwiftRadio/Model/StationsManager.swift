//
//  StationsManager.swift
//  SwiftRadio
//
//  Created by Fethi El Hassasna on 2022-11-02.
//  Copyright © 2022 matthewfecher.com. All rights reserved.
//

import UIKit
import FRadioPlayer
import MediaPlayer

protocol StationsManagerObserver: AnyObject {
    func stationsManager(_ manager: StationsManager, stationsDidUpdate stations: [RadioStation])
    func stationsManager(_ manager: StationsManager, stationDidChange station: RadioStation?)
}

extension StationsManagerObserver {
    func stationsManager(_ manager: StationsManager, stationsDidUpdate stations: [RadioStation]) {}
}

class StationsManager {
    
    static let shared = StationsManager()
    
    private(set) var stations: [RadioStation] = [] {
        didSet {
            notifiyObservers { observer in
                observer.stationsManager(self, stationsDidUpdate: stations)
            }
        }
    }
    
    private(set) var currentStation: RadioStation? {
        didSet {
            let station = currentStation
            Task { @MainActor in
                StationNowPlayingService.shared.bind(to: station)
            }

            notifiyObservers { observer in
                observer.stationsManager(self, stationDidChange: currentStation)
            }

            reloadStationArtworkIntoLockScreen()
        }
    }
    
    var searchedStations: [RadioStation] = []
    
    private var observations = [ObjectIdentifier : Observation]()
    private let player = FRadioPlayer.shared
    private var playbackQualityObserver: NSObjectProtocol?
    private var externalNowPlayingObserver: NSObjectProtocol?

    private init() {
        self.player.addObserver(self)
        playbackQualityObserver = NotificationCenter.default.addObserver(
            forName: .playbackQualityPreferenceDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyCurrentStreamQualityIfNeeded()
        }

        externalNowPlayingObserver = NotificationCenter.default.addObserver(
            forName: .externalNowPlayingMetadataDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateNowPlayingMetadataAndTimingPreservingArtwork()
        }
    }

    /// Re-applies the current station URL when the user changes stream quality in Settings.
    func applyCurrentStreamQualityIfNeeded() {
        guard let station = currentStation else { return }
        applyStreamURL(for: station)
    }

    private func applyStreamURL(for station: RadioStation) {
        let urlString = station.resolvedStreamURL(for: PlaybackPreferences.shared.streamQualityMode)
        guard let url = URL(string: urlString) else { return }
        if player.radioURL != url {
            player.radioURL = url
        }
    }
    
    @MainActor
    func fetch() async throws {
        let stations = try await NetworkService.fetchStations()
        guard self.stations != stations else { return }
        self.stations = stations
        if let currentStation, !stations.contains(currentStation) { reset() }
    }

    func fetch(_ completion: ((Result<[RadioStation], Error>) -> Void)? = nil) {
        Task { @MainActor in
            do {
                try await fetch()
                completion?(.success(stations))
            } catch {
                completion?(.failure(error))
            }
        }
    }
    
    func set(station: RadioStation?) {
        guard let station = station else {
            reset()
            return
        }

        currentStation = station
        applyStreamURL(for: station)
    }

    func setNext() {
        guard let index = getIndex(of: currentStation) else { return }
        let station = (index + 1 == stations.count) ? stations[0] : stations[index + 1]
        currentStation = station
        applyStreamURL(for: station)
    }

    func setPrevious() {
        guard let index = getIndex(of: currentStation), let station = (index == 0) ? stations.last : stations[index - 1] else { return }
        currentStation = station
        applyStreamURL(for: station)
    }
    
    func updateSearch(with filter: String) {
        searchedStations.removeAll(keepingCapacity: false)
        searchedStations = stations.filter { $0.name.range(of: filter, options: [.caseInsensitive]) != nil }
    }
    
    private func reset() {
        currentStation = nil
        player.radioURL = nil
    }
    
    private func getIndex(of station: RadioStation?) -> Int? {
        guard let station = station, let index = stations.firstIndex(of: station) else { return nil }
        return index
    }
}

// MARK: - StationsManager Observation

extension StationsManager {
    
    private struct Observation {
        weak var observer: StationsManagerObserver?
    }
    
    func addObserver(_ observer: StationsManagerObserver) {
        let id = ObjectIdentifier(observer)
        observations[id] = Observation(observer: observer)
    }
    
    func removeObserver(_ observer: StationsManagerObserver) {
        let id = ObjectIdentifier(observer)
        observations.removeValue(forKey: id)
    }
    
    private func notifiyObservers(with action: (_ observer: StationsManagerObserver) -> Void) {
        for (id, observation) in observations {
            guard let observer = observation.observer else {
                observations.removeValue(forKey: id)
                continue
            }
            
            action(observer)
        }
    }
}

// MARK: - MPNowPlayingInfoCenter (Lock screen / CarPlay)

extension StationsManager {

    /// Loads station branding artwork into Now Playing (station changes, or stream artwork cleared).
    private func reloadStationArtworkIntoLockScreen() {
        guard let station = currentStation else {
            updateLockScreen(withArtwork: nil, rebuildFromScratch: true)
            return
        }

        station.getImage { [weak self] image in
            self?.updateLockScreen(withArtwork: image, rebuildFromScratch: true)
        }
    }

    /// Updates title / artist / timing only — **does not** replace artwork. Prevents CarPlay / lock screen flipping between station logo and track art on each metadata packet.
    private func updateNowPlayingMetadataAndTimingPreservingArtwork() {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]

        if let station = currentStation {
            info[MPMediaItemPropertyArtist] = station.artistName
            info[MPMediaItemPropertyTitle] = station.trackName
        }

        let isLive = player.duration == 0
        if isLive {
            info[MPNowPlayingInfoPropertyIsLiveStream] = true
            info.removeValue(forKey: MPNowPlayingInfoPropertyElapsedPlaybackTime)
            info.removeValue(forKey: MPMediaItemPropertyPlaybackDuration)
            info.removeValue(forKey: MPNowPlayingInfoPropertyPlaybackRate)
        } else {
            info.removeValue(forKey: MPNowPlayingInfoPropertyIsLiveStream)
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime
            info[MPMediaItemPropertyPlaybackDuration] = player.duration
            info[MPNowPlayingInfoPropertyPlaybackRate] = player.rate ?? 1
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        AudioSetupService.shared.updateLiveCommands(isLive: isLive)
    }

    private func updateLockScreen(withArtwork artworkImage: UIImage?, rebuildFromScratch: Bool) {
        var nowPlayingInfo: [String: Any]
        if rebuildFromScratch {
            nowPlayingInfo = [:]
            if let image = artworkImage {
                nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size, requestHandler: { _ in image })
            }
        } else {
            nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
            if let image = artworkImage {
                nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size, requestHandler: { _ in image })
            }
        }

        if let station = currentStation {
            nowPlayingInfo[MPMediaItemPropertyArtist] = station.artistName
            nowPlayingInfo[MPMediaItemPropertyTitle] = station.trackName
        }

        let isLive = player.duration == 0
        if isLive {
            nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = true
        } else {
            nowPlayingInfo.removeValue(forKey: MPNowPlayingInfoPropertyIsLiveStream)
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = player.duration
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player.rate ?? 1
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        AudioSetupService.shared.updateLiveCommands(isLive: isLive)
    }
}

// MARK: - FRadioPlayerObserver

extension StationsManager: FRadioPlayerObserver {

    func radioPlayer(_ player: FRadioPlayer, metadataDidChange metadata: FRadioPlayer.Metadata?) {
        updateNowPlayingMetadataAndTimingPreservingArtwork()
    }

    func radioPlayer(_ player: FRadioPlayer, artworkDidChange artworkURL: URL?) {
        guard let artworkURL else {
            reloadStationArtworkIntoLockScreen()
            return
        }

        Task { [weak self] in
            guard let self else { return }
            guard let image = await NetworkService.fetchImage(from: artworkURL) else {
                await MainActor.run { self.reloadStationArtworkIntoLockScreen() }
                return
            }
            await MainActor.run { self.updateLockScreen(withArtwork: image, rebuildFromScratch: true) }
        }
    }

    func radioPlayer(_ player: FRadioPlayer, playTimeDidChange currentTime: TimeInterval, duration: TimeInterval) {
        guard duration != 0 else {
            updateNowPlayingMetadataAndTimingPreservingArtwork()
            return
        }
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyPlaybackRate] = player.rate ?? 1
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
