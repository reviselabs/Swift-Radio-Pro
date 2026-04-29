//
//  StarterFMSchedule.swift
//  SwiftRadio
//

import Foundation

/// Weekly grid JSON for Starter FM (bundled `StarterFMSchedule.json`, replaceable).
struct StarterFMScheduleDocument: Codable {
    let timezone: String
    let days: [StarterFMDay]
}

struct StarterFMDay: Codable {
    let dayKey: String
    let day: String
    let schedulePostId: Int
    let schedulePostTitle: String
    let slots: [StarterFMShowSlot]

    enum CodingKeys: String, CodingKey {
        case dayKey = "day_key"
        case day
        case schedulePostId = "schedule_post_id"
        case schedulePostTitle = "schedule_post_title"
        case slots
    }
}

struct StarterFMShowSlot: Codable, Hashable {
    let showId: Int
    let showUrl: String
    let title: String
    let start: String
    let end: String
    let timeRange: String
    let image: String
    let description: String

    enum CodingKeys: String, CodingKey {
        case showId = "show_id"
        case showUrl = "show_url"
        case title
        case start
        case end
        case timeRange = "time_range"
        case image
        case description
    }
}
