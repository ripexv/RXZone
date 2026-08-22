//
//  WorkingHours.swift
//  RXZone
//

import Foundation

/// When someone in a tracked zone is at work, in that zone's own local time.
///
/// One range, deliberately. A second range for sleep would let the app claim
/// somebody is asleep, and that is a guess — the rest of RXZone only shows what
/// it can actually derive, so this stops at "working" and "off hours".
nonisolated struct WorkingHours: Codable, Hashable, Sendable {

    /// Minutes from local midnight, `0..<1440`.
    var start: Int
    var end: Int

    /// Skip Saturday and Sunday. A single switch covers what nearly everyone
    /// means; a per-weekday schedule would be far more UI for far less use.
    var weekdaysOnly: Bool

    init(start: Int = 9 * 60, end: Int = 18 * 60, weekdaysOnly: Bool = true) {
        self.start = start
        self.end = end
        self.weekdaysOnly = weekdaysOnly
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let start = (try? container.decode(Int.self, forKey: .start)) ?? 9 * 60
        let end = (try? container.decode(Int.self, forKey: .end)) ?? 18 * 60
        self.start = Self.clamped(start)
        self.end = Self.clamped(end)
        self.weekdaysOnly = (try? container.decode(Bool.self, forKey: .weekdaysOnly)) ?? true
    }

    private static func clamped(_ minutes: Int) -> Int { min(max(minutes, 0), 24 * 60 - 1) }

    /// True when the range runs past midnight, e.g. a 22:00–06:00 shift.
    var wrapsMidnight: Bool { end <= start }

    /// Whether this zone is inside working hours at `date`.
    func isActive(at date: Date, in timeZone: TimeZone) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.hour, .minute, .weekday], from: date)
        guard let hour = parts.hour, let minute = parts.minute, let weekday = parts.weekday else {
            return false
        }

        let minuteOfDay = hour * 60 + minute
        let inRange = wrapsMidnight
            ? (minuteOfDay >= start || minuteOfDay < end)
            : (minuteOfDay >= start && minuteOfDay < end)
        guard inRange else { return false }
        guard weekdaysOnly else { return true }

        // The tail of an overnight shift belongs to the day it began on, so a
        // Friday 22:00–06:00 shift is still a work shift at 02:00 on Saturday.
        let startedOnPreviousDay = wrapsMidnight && minuteOfDay < end
        let day = startedOnPreviousDay ? (weekday == 1 ? 7 : weekday - 1) : weekday
        // `Calendar` numbers Sunday as 1 and Saturday as 7.
        return day != 1 && day != 7
    }
}
