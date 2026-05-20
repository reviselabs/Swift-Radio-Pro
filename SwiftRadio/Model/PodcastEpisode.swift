//
//  PodcastEpisode.swift
//  SwiftRadio
//
//  Created by RadioCopilot on 2026-04-29.
//

import Foundation

struct PodcastEpisode: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String?
    let pubDate: Date?
    let pubDateRaw: String?
    let linkURL: URL?
    let audioURL: URL?
    let duration: String?
    let artworkURL: URL?
}

