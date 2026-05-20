//
//  HomeStore.swift
//  SwiftRadio
//

import Foundation

extension Notification.Name {
    static let homeStoreDidChange = Notification.Name("homeStoreDidChange")
}

final class HomeStore {
    static let shared = HomeStore()

    private let defaults = UserDefaults.standard
    private let key = "addedPodcastIDs"

    private init() {}

    private var addedIDs: [String] {
        get { defaults.stringArray(forKey: key) ?? [] }
        set {
            defaults.set(newValue, forKey: key)
            NotificationCenter.default.post(name: .homeStoreDidChange, object: nil)
        }
    }

    func isAdded(_ podcast: Podcast) -> Bool {
        addedIDs.contains(podcast.id)
    }

    func setAdded(_ podcast: Podcast, added: Bool) {
        var ids = addedIDs
        if added {
            if !ids.contains(podcast.id) { ids.append(podcast.id) }
        } else {
            ids.removeAll { $0 == podcast.id }
        }
        addedIDs = ids
    }

    func toggleAdded(_ podcast: Podcast) {
        setAdded(podcast, added: !isAdded(podcast))
    }

    func addedPodcasts(from allPodcasts: [Podcast]) -> [Podcast] {
        addedIDs.compactMap { id in allPodcasts.first { $0.id == id } }
    }
}
