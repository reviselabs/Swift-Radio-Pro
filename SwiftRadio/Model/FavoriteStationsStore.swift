//
//  FavoriteStationsStore.swift
//  SwiftRadio
//

import Foundation

extension Notification.Name {
    static let favoriteStationsDidChange = Notification.Name("favoriteStationsDidChange")
}

/// Persists favorite stations by stable `streamURL` (unique per station in data).
final class FavoriteStationsStore {

    static let shared = FavoriteStationsStore()

    private let defaults = UserDefaults.standard
    private let key = "favoriteStationStreamURLs"

    private init() {}

    private var orderedFavoriteStreamURLs: [String] {
        get { defaults.stringArray(forKey: key) ?? [] }
        set {
            defaults.set(newValue, forKey: key)
            NotificationCenter.default.post(name: .favoriteStationsDidChange, object: nil)
        }
    }

    func isFavorite(_ station: RadioStation) -> Bool {
        orderedFavoriteStreamURLs.contains(station.streamURL)
    }

    func setFavorite(_ station: RadioStation, isFavorite: Bool) {
        var order = orderedFavoriteStreamURLs
        let id = station.streamURL
        if isFavorite {
            if !order.contains(id) {
                order.append(id)
            }
        } else {
            order.removeAll { $0 == id }
        }
        orderedFavoriteStreamURLs = order
    }

    func toggleFavorite(_ station: RadioStation) {
        setFavorite(station, isFavorite: !isFavorite(station))
    }

    /// Favorites first (preserving favorite order), then remaining stations in original order.
    func stationsAllTabOrdering(_ stations: [RadioStation]) -> [RadioStation] {
        let favIds = Set(orderedFavoriteStreamURLs)
        let favOrdered = orderedFavoriteStreamURLs.compactMap { url in stations.first { $0.streamURL == url } }
        let rest = stations.filter { !favIds.contains($0.streamURL) }
        return favOrdered + rest
    }

    func stationsFavoritesOnly(from stations: [RadioStation]) -> [RadioStation] {
        let favIds = orderedFavoriteStreamURLs
        return favIds.compactMap { url in stations.first { $0.streamURL == url } }
    }
}
