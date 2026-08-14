//
//  DateFormatting.swift
//  RXZone
//

import Foundation

/// Rendering helpers for clock, date and offset strings.
///
/// All calendar maths goes through `TimeZone` and `Calendar`, which apply the
/// system tz database. Daylight saving transitions are therefore handled by
/// Foundation and are never computed here.
///
/// Main-actor isolated (the project default) because every caller is a SwiftUI
/// view and the locale cache below is not synchronized.
enum DateFormatting {

    // MARK: - Time

    /// e.g. `15:43`, `3:43 PM`, or `15:43:07` when seconds are shown.
    ///
    /// `.system` defers entirely to the user's locale, so it matches the macOS
    /// clock including that locale's own padding habits. The explicit 12- and
    /// 24-hour choices instead pin the field widths: a 24-hour clock reads
    /// `08:43`, not `8:43`, and the menu bar keeps a stable width all day.
    static func timeString(
        for date: Date,
        in timeZone: TimeZone,
        format: TimeFormat,
        showsSeconds: Bool = false
    ) -> String {
        let locale = locale(for: format)

        guard format != .system else {
            return date.formatted(Date.FormatStyle(
                date: .omitted,
                time: showsSeconds ? .standard : .shortened,
                locale: locale,
                timeZone: timeZone
            ))
        }

        // Omitting the AM/PM field selects the 24-hour hour symbol; requesting
        // it selects the 12-hour one, with wording taken from the locale.
        let hour: Date.FormatStyle.Symbol.Hour = format == .twentyFourHour
            ? .twoDigits(amPM: .omitted)
            : .defaultDigits(amPM: .abbreviated)

        var style = Date.FormatStyle(locale: locale, timeZone: timeZone)
            .hour(hour)
            .minute(.twoDigits)
        if showsSeconds { style = style.second(.twoDigits) }
        return date.formatted(style)
    }

    // MARK: - Date

    /// e.g. `Friday, Aug 14` — weekday and month order follow the user's locale.
    static func dateString(for date: Date, in timeZone: TimeZone) -> String {
        let style = Date.FormatStyle(locale: .current, timeZone: timeZone)
            .weekday(.wide)
            .month(.abbreviated)
            .day()
        return date.formatted(style)
    }

    /// How many calendar days the zone is ahead of (`+`) or behind (`-`) the
    /// reference zone at the same instant.
    ///
    /// Compares calendar dates rather than elapsed time, so it stays correct
    /// across DST transitions and sub-hour offsets.
    static func dayDelta(at date: Date, zone: TimeZone, reference: TimeZone) -> Int {
        guard zone.identifier != reference.identifier else { return 0 }

        var zoneCalendar = Calendar.current
        zoneCalendar.timeZone = zone
        var referenceCalendar = Calendar.current
        referenceCalendar.timeZone = reference

        let fields: Set<Calendar.Component> = [.year, .month, .day]
        let zoneDay = zoneCalendar.dateComponents(fields, from: date)
        let referenceDay = referenceCalendar.dateComponents(fields, from: date)

        // Re-anchor both civil dates in a single fixed calendar so the
        // difference is a pure day count, free of any zone's own offsets.
        var anchor = Calendar(identifier: .gregorian)
        anchor.timeZone = .gmt
        guard let zoneAnchor = anchor.date(from: DateComponents(
                  year: zoneDay.year, month: zoneDay.month, day: zoneDay.day)),
              let referenceAnchor = anchor.date(from: DateComponents(
                  year: referenceDay.year, month: referenceDay.month, day: referenceDay.day))
        else { return 0 }

        return anchor.dateComponents([.day], from: referenceAnchor, to: zoneAnchor).day ?? 0
    }

    /// Short marker for a zone sitting on a different calendar day, or `nil`
    /// when it shares the reference zone's day.
    static func dayDeltaLabel(_ delta: Int) -> String? {
        switch delta {
        case 0: nil
        case 1: String(localized: "Tomorrow", comment: "Zone is one day ahead")
        case -1: String(localized: "Yesterday", comment: "Zone is one day behind")
        case let value where value > 0:
            String(localized: "+\(value) days", comment: "Zone is several days ahead")
        case let value:
            String(localized: "\(value) days", comment: "Zone is several days behind")
        }
    }

    // MARK: - Offsets

    /// Difference between two zones at a given instant, e.g. `+3h`, `-5h30m`.
    /// Uses `secondsFromGMT(for:)` so the answer reflects DST on that date.
    static func offsetLabel(of zone: TimeZone, from reference: TimeZone, at date: Date) -> String {
        let seconds = zone.secondsFromGMT(for: date) - reference.secondsFromGMT(for: date)
        guard seconds != 0 else {
            return String(localized: "Same time", comment: "Zone has no offset from the reference zone")
        }

        let sign = seconds < 0 ? "−" : "+"
        return sign + durationLabel(minutes: abs(seconds) / 60)
    }

    /// Signed description of the time travel offset, e.g. `+3h 15m`.
    static func travelLabel(minutes: Int) -> String {
        guard minutes != 0 else {
            return String(localized: "Now", comment: "Time travel slider is at the present moment")
        }
        let sign = minutes < 0 ? "−" : "+"
        return sign + durationLabel(minutes: abs(minutes), separator: " ")
    }

    /// `90` -> `1h30m`. Whole hours drop the minute component.
    private static func durationLabel(minutes: Int, separator: String = "") -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        switch (hours, remainder) {
        case (0, let value): return "\(value)m"
        case (let value, 0): return "\(value)h"
        case (let hour, let value): return "\(hour)h\(separator)\(value)m"
        }
    }

    // MARK: - Locale

    /// Locales that force a 12- or 24-hour clock, derived from the user's own
    /// locale so date order, numerals and AM/PM wording stay correct.
    private static var localeCache: [TimeFormat: Locale] = [:]

    private static func locale(for format: TimeFormat) -> Locale {
        guard let hourCycle = format.hourCycle else { return .current }
        if let cached = localeCache[format] { return cached }

        var components = Locale.Components(locale: .current)
        components.hourCycle = hourCycle
        let locale = Locale(components: components)
        localeCache[format] = locale
        return locale
    }

    /// Drops cached locales after the user changes region or clock settings.
    static func invalidateLocaleCache() { localeCache.removeAll() }
}
