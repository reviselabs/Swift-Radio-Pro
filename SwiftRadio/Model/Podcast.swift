//
//  Podcast.swift
//  SwiftRadio
//
//  Created by RadioCopilot on 2026-04-29.
//

import Foundation

struct Podcast: Identifiable, Hashable {
    let id: String
    let title: String
    let feedURL: URL
    let artworkURL: URL?
}

