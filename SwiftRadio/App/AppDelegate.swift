//
//  AppDelegate.swift
//  Swift Radio
//
//  Created by Matthew Fecher on 7/2/15.
//  Copyright (c) 2015 MatthewFecher.com. All rights reserved.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    private static let legacyURLCachePurgeKey = "SwiftRadio.legacyURLCachePurge.v1"

    private let audioService = AudioSetupService.shared

    /// Replaces `URLCache.shared` with a small on-disk cap on every launch. One-time purge clears pre‑migration CFNetwork cache bloat.
    private static func configureBoundedSharedURLCache() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = caches.appendingPathComponent("SwiftRadioHTTP", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if !UserDefaults.standard.bool(forKey: legacyURLCachePurgeKey) {
            URLCache.shared.removeAllCachedResponses()
            UserDefaults.standard.set(true, forKey: legacyURLCachePurgeKey)
        }
        URLCache.shared = URLCache(
            memoryCapacity: 6 * 1024 * 1024,
            diskCapacity: 20 * 1024 * 1024,
            directory: dir
        )
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Self.configureBoundedSharedURLCache()

        // Override point for customization after application launch.
        // Setup all audio-related configurations at app launch
        audioService.setupFRadioPlayer()
        audioService.setupAudioSession()
        audioService.setupRemoteCommandCenter()
        
        return true
    }
    
    // MARK: UISceneSession Lifecycle
    
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
#if CarPlay
        if connectingSceneSession.role == .carTemplateApplication {
            let config = UISceneConfiguration(name: "CarPlay Configuration", sessionRole: connectingSceneSession.role)
            config.delegateClass = CarPlaySceneDelegate.self
            return config
        }
#endif
        
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication,
                     didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }
}
