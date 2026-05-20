//
//  CarPlaySceneDelegate.swift
//  Swift Radio
//
//  Created by Fethi El Hassasna on 1/25/25.
//  Copyright (c) 2015 MatthewFecher.com. All rights reserved.
//
//

import CarPlay
import FRadioPlayer

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    private var interfaceController: CPInterfaceController?

    /// Avoid rebuilding the list (and re-fetching images) when nothing about stations changed.
    private var lastStationListSignature: String = ""

    /// Station logos cached so list rows don’t flash between branding art and async reloads. `NSCache` caps memory vs. an unbounded dictionary.
    private let stationImageCache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 48
        return c
    }()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let templateApplicationScene = scene as? CPTemplateApplicationScene else { return }
        templateApplicationScene.delegate = self
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController

        let listTemplate = CPListTemplate(title: Content.Stations.title, sections: [])

        interfaceController.setRootTemplate(listTemplate, animated: false, completion: nil)

        if StationsManager.shared.stations.isEmpty {
            StationsManager.shared.fetch { [weak self] _ in
                self?.updateStationsListIfNeeded(listTemplate)
            }
        } else {
            updateStationsListIfNeeded(listTemplate)
        }

        StationsManager.shared.addObserver(self)
    }

    private func signature(for stations: [RadioStation]) -> String {
        stations.map(\.streamURL).joined(separator: "|")
    }

    private func updateStationsListIfNeeded(_ template: CPListTemplate) {
        let stations = StationsManager.shared.stations
        let sig = signature(for: stations)
        guard sig != lastStationListSignature || template.sections.isEmpty else { return }
        lastStationListSignature = sig

        let items = stations.map { station -> CPListItem in
            let item = CPListItem(text: station.name, detailText: station.desc)

            let cacheKey = station.streamURL as NSString
            if let cached = stationImageCache.object(forKey: cacheKey) {
                item.setImage(cached)
            } else if let assetName = station.imageURL.contains("http") ? nil : station.imageURL,
                      let image = UIImage(named: assetName) {
                stationImageCache.setObject(image, forKey: cacheKey)
                item.setImage(image)
            } else {
                station.getImage { [weak self, weak template] image in
                    guard let self, let template else { return }
                    self.stationImageCache.setObject(image, forKey: cacheKey)
                    item.setImage(image)
                    if let currentItems = template.sections.first?.items {
                        template.updateSections([CPListSection(items: currentItems)])
                    }
                }
            }

            item.handler = { _, completion in
                StationsManager.shared.set(station: station)
                completion()
            }

            return item
        }

        let section = CPListSection(items: items)
        template.updateSections([section])
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        self.interfaceController = nil
        StationsManager.shared.removeObserver(self)
    }
}

// MARK: - StationsManagerObserver

extension CarPlaySceneDelegate: StationsManagerObserver {

    func stationsManager(_ manager: StationsManager, stationsDidUpdate stations: [RadioStation]) {
        if let listTemplate = interfaceController?.rootTemplate as? CPListTemplate {
            DispatchQueue.main.async {
                self.updateStationsListIfNeeded(listTemplate)
            }
        }
    }

    func stationsManager(_ manager: StationsManager, stationDidChange station: RadioStation?) {}
}
