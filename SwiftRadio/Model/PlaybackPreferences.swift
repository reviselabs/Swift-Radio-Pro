//
//  PlaybackPreferences.swift
//  SwiftRadio
//

import Foundation

enum StreamQualityMode: String, CaseIterable, Codable {
    case auto
    case low
    case medium
    case high

    var analyticsKey: String { rawValue }
}

final class PlaybackPreferences {

    static let shared = PlaybackPreferences()

    private let defaults = UserDefaults.standard
    private let qualityKey = "streamQualityMode"

    private init() {}

    var streamQualityMode: StreamQualityMode {
        get {
            guard let raw = defaults.string(forKey: qualityKey),
                  let mode = StreamQualityMode(rawValue: raw) else {
                return .auto
            }
            return mode
        }
        set {
            defaults.set(newValue.rawValue, forKey: qualityKey)
            NotificationCenter.default.post(name: .playbackQualityPreferenceDidChange, object: nil)
        }
    }
}

extension Notification.Name {
    static let playbackQualityPreferenceDidChange = Notification.Name("playbackQualityPreferenceDidChange")
}
