//
//  StarterFMScheduleEngine.swift
//  SwiftRadio
//

import Foundation

enum StarterFMScheduleEngine {

    /// Maps `Calendar` weekday (1 = Sunday … 7 = Saturday) to JSON `day_key`.
    private static let weekdayToDayKey: [Int: String] = [
        1: "sun",
        2: "mon",
        3: "tue",
        4: "wed",
        5: "thu",
        6: "fri",
        7: "sat",
    ]

    private static func sydneyCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Australia/Sydney") ?? .current
        return cal
    }

    static func dayKey(for date: Date, calendar: Calendar) -> String? {
        let wd = calendar.component(.weekday, from: date)
        return weekdayToDayKey[wd]
    }

    static func day(forKey key: String, in document: StarterFMScheduleDocument) -> StarterFMDay? {
        document.days.first { $0.dayKey == key }
    }

    /// Minutes from midnight for `"HH:mm"`.
    static func minutes(fromHHmm hm: String) -> Int? {
        let parts = hm.split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0]),
              let m = Int(parts[1]),
              (0..<24).contains(h),
              (0..<60).contains(m) else { return nil }
        return h * 60 + m
    }

    /// Slot crosses calendar midnight when end is at or before start on the same clock (e.g. 23:00 → 01:00).
    private static func crossesMidnight(start: String, end: String) -> Bool {
        guard let sm = minutes(fromHHmm: start), let em = minutes(fromHHmm: end) else { return false }
        return em <= sm
    }

    private static func date(startOfDay: Date, minutesFromMidnight: Int, calendar: Calendar) -> Date {
        calendar.date(byAdding: .minute, value: minutesFromMidnight, to: startOfDay) ?? startOfDay
    }

    /// Which slot is on air in the document’s timezone (`document.timezone` should be Sydney).
    static func currentSlot(in document: StarterFMScheduleDocument, now: Date = Date()) -> StarterFMShowSlot? {
        let cal = sydneyCalendar()
        let todayStart = cal.startOfDay(for: now)
        guard let yesterdayStart = cal.date(byAdding: .day, value: -1, to: todayStart),
              let yesterdayKey = dayKey(for: yesterdayStart, calendar: cal),
              let todayKey = dayKey(for: todayStart, calendar: cal) else { return nil }

        // 1) Yesterday’s programmes that spill past midnight into this morning
        if let yDay = day(forKey: yesterdayKey, in: document) {
            for slot in yDay.slots {
                guard crossesMidnight(start: slot.start, end: slot.end),
                      let sm = minutes(fromHHmm: slot.start),
                      let em = minutes(fromHHmm: slot.end) else { continue }
                let begin = date(startOfDay: yesterdayStart, minutesFromMidnight: sm, calendar: cal)
                let duration = TimeInterval((24 * 60 - sm + em) * 60)
                let end = begin.addingTimeInterval(duration)
                if now >= begin && now < end { return slot }
            }
        }

        // 2) Today’s same-calendar-day slots
        guard let tDay = day(forKey: todayKey, in: document) else { return nil }

        for slot in tDay.slots {
            guard let sm = minutes(fromHHmm: slot.start), let em = minutes(fromHHmm: slot.end) else { continue }
            if em > sm {
                let begin = date(startOfDay: todayStart, minutesFromMidnight: sm, calendar: cal)
                let end = date(startOfDay: todayStart, minutesFromMidnight: em, calendar: cal)
                if now >= begin && now < end { return slot }
            }
        }

        // 3) Today’s late-evening slots that run past midnight
        for slot in tDay.slots {
            guard crossesMidnight(start: slot.start, end: slot.end),
                  let sm = minutes(fromHHmm: slot.start),
                  let em = minutes(fromHHmm: slot.end) else { continue }
            let begin = date(startOfDay: todayStart, minutesFromMidnight: sm, calendar: cal)
            let duration = TimeInterval((24 * 60 - sm + em) * 60)
            let end = begin.addingTimeInterval(duration)
            if now >= begin && now < end { return slot }
        }

        return nil
    }

    static func signature(for slot: StarterFMShowSlot?) -> String {
        guard let slot else { return "" }
        return "\(slot.showId)|\(slot.start)|\(slot.end)|\(slot.title)"
    }

    /// Puts **today** (Sydney) first, then the rest of the week — easier to scan “now / later”.
    static func daysOrderedFromToday(_ document: StarterFMScheduleDocument, now: Date = Date()) -> [StarterFMDay] {
        let cal = sydneyCalendar()
        let dayStart = cal.startOfDay(for: now)
        guard let todayKey = dayKey(for: dayStart, calendar: cal),
              let idx = document.days.firstIndex(where: { $0.dayKey == todayKey }) else {
            return document.days
        }
        return Array(document.days[idx...]) + Array(document.days[..<idx])
    }
}
