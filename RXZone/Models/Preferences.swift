//
//  Preferences.swift
//  RXZone
//

import Foundation

/// How clock times are rendered.
nonisolated enum TimeFormat: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Follow whatever the user picked in System Settings.
    case system
    case twelveHour
    case twentyFourHour

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: String(localized: "System", comment: "Time format option")
        case .twelveHour: String(localized: "12-hour", comment: "Time format option")
        case .twentyFourHour: String(localized: "24-hour", comment: "Time format option")
        }
    }

    /// `nil` means "do not override the locale's own hour cycle".
    var hourCycle: Locale.HourCycle? {
        switch self {
        case .system: nil
        case .twelveHour: .oneToTwelve
        case .twentyFourHour: .zeroToTwentyThree
        }
    }
}

/// What the status item itself shows in the menu bar.
nonisolated enum MenuBarStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case icon
    case time
    case symbolAndTime
    case labelAndTime

    var id: String { rawValue }

    var label: String {
        switch self {
        case .icon: String(localized: "Icon only", comment: "Menu bar appearance option")
        case .time: String(localized: "Time", comment: "Menu bar appearance option")
        case .symbolAndTime: String(localized: "Emoji and time", comment: "Menu bar appearance option")
        case .labelAndTime: String(localized: "Name and time", comment: "Menu bar appearance option")
        }
    }

    var showsTime: Bool { self != .icon }
}

/// Granularity of the time travel slider.
nonisolated enum TravelStep: Int, Codable, CaseIterable, Identifiable, Sendable {
    case fiveMinutes = 5
    case quarterHour = 15
    case halfHour = 30
    case hour = 60

    var id: Int { rawValue }

    var minutes: Double { Double(rawValue) }

    var label: String {
        switch self {
        case .fiveMinutes: String(localized: "5 minutes", comment: "Time travel step size")
        case .quarterHour: String(localized: "15 minutes", comment: "Time travel step size")
        case .halfHour: String(localized: "30 minutes", comment: "Time travel step size")
        case .hour: String(localized: "1 hour", comment: "Time travel step size")
        }
    }
}

/// Everything the app persists, stored as a single JSON blob in `UserDefaults`.
///
/// Decoding is written by hand so that a payload missing any key falls back to
/// that property's default instead of throwing and losing the entire config.
nonisolated struct Preferences: Codable, Equatable, Sendable {
    var zones: [TimeZoneItem] = TimeZoneItem.starterZones
    var timeFormat: TimeFormat = .system

    /// Show a pinned row for the Mac's own time zone at the top of the list.
    var showsLocalZone: Bool = true
    /// Show the weekday and date under each time.
    var showsDate: Bool = true
    /// Show how far each zone is from the reference zone, e.g. `+3h`.
    var showsOffsetFromLocal: Bool = true
    var showsSecondsInPopover: Bool = false

    var menuBarStyle: MenuBarStyle = .symbolAndTime
    /// Which zones the menu bar shows, side by side. Empty means just the Mac's
    /// own time zone, which is what a fresh install starts with.
    var menuBarZoneIDs: Set<UUID> = []
    var menuBarShowsSeconds: Bool = false

    /// Keeps the time travel slider mounted in the popover. Off by default so
    /// the popover stays a plain list of clocks; the footer button reveals it.
    var showsTimeTravel: Bool = false
    var travelStep: TravelStep = .quarterHour
    /// Snap the time travel slider back to "now" whenever the popover closes.
    var travelResetsOnClose: Bool = true

    /// System-wide shortcut that opens and closes the popover.
    var globalShortcut: ShortcutPreset = .off

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // `@autoclosure` keeps the fallbacks lazy, so decoding a saved payload
        // never builds the starter zone list (and with it the whole catalog).
        func value<T: Decodable>(_ key: CodingKeys, default fallback: @autoclosure () -> T) -> T {
            // `try?` flattens the decoder's optional, so a missing key and a
            // malformed value both arrive here as nil.
            guard let decoded = try? container.decodeIfPresent(T.self, forKey: key) else {
                return fallback()
            }
            return decoded
        }

        zones = value(.zones, default: TimeZoneItem.starterZones)
        timeFormat = value(.timeFormat, default: .system)
        showsLocalZone = value(.showsLocalZone, default: true)
        showsDate = value(.showsDate, default: true)
        showsOffsetFromLocal = value(.showsOffsetFromLocal, default: true)
        showsSecondsInPopover = value(.showsSecondsInPopover, default: false)
        menuBarStyle = value(.menuBarStyle, default: .symbolAndTime)
        menuBarZoneIDs = value(.menuBarZoneIDs, default: [])
        menuBarShowsSeconds = value(.menuBarShowsSeconds, default: false)
        showsTimeTravel = value(.showsTimeTravel, default: false)
        travelStep = value(.travelStep, default: .quarterHour)
        travelResetsOnClose = value(.travelResetsOnClose, default: true)
        globalShortcut = value(.globalShortcut, default: .off)
    }
}
