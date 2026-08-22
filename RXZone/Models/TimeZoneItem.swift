//
//  TimeZoneItem.swift
//  RXZone
//

import Foundation

/// A single time zone the user chose to track.
///
/// Only the identifier is stored; everything else (current offset, DST state,
/// localized city name) is derived from Foundation's time zone database at
/// display time so the app never has to reason about DST rules itself.
nonisolated struct TimeZoneItem: Identifiable, Codable, Hashable, Sendable {
    let id: UUID

    /// A Foundation time zone identifier such as `Europe/Istanbul`.
    var identifier: String

    /// Optional user supplied name. When empty the localized city name is used.
    var customLabel: String

    /// Emoji shown at the start of the row. Defaults to the region's flag.
    ///
    /// Clamped on every write: the Settings field is a free-form `TextField`,
    /// and without this a pasted paragraph would end up in the menu bar.
    /// Assigning inside `didSet` does not re-enter it, so this terminates.
    var symbol: String {
        didSet { symbol = Self.sanitizedSymbol(symbol) }
    }

    /// When this row is at work, in its own local time. `nil` means the user
    /// has not said, and the row shows no status rather than a guessed one.
    var workingHours: WorkingHours?

    init(
        id: UUID = UUID(),
        identifier: String,
        customLabel: String = "",
        symbol: String? = nil,
        workingHours: WorkingHours? = nil
    ) {
        self.id = id
        self.identifier = identifier
        self.customLabel = customLabel
        self.symbol = Self.sanitizedSymbol(symbol ?? TimeZoneCatalog.suggestedSymbol(for: identifier))
        self.workingHours = workingHours
    }

    /// At most two glyphs, no whitespace or line breaks. Counting is by
    /// `Character`, so a flag emoji — two Unicode scalars — counts as one.
    static func sanitizedSymbol(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(2))
    }

    // Decoded defensively: a stored payload written by an older build may be
    // missing keys, and that should degrade gracefully rather than discard the
    // user's whole zone list.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let identifier = try container.decode(String.self, forKey: .identifier)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.identifier = identifier
        self.customLabel = try container.decodeIfPresent(String.self, forKey: .customLabel) ?? ""
        // `didSet` does not run during initialization, so clamp explicitly —
        // a stored payload could predate the limit or have been edited by hand.
        self.symbol = Self.sanitizedSymbol(
            try container.decodeIfPresent(String.self, forKey: .symbol)
                ?? TimeZoneCatalog.suggestedSymbol(for: identifier)
        )
        self.workingHours = try? container.decodeIfPresent(WorkingHours.self, forKey: .workingHours)
    }

    /// `nil` when the stored identifier is no longer present in the system
    /// database, which can happen after a tz database update removes a zone.
    var timeZone: TimeZone? { TimeZone(identifier: identifier) }

    /// Never traps. Unknown identifiers fall back to GMT and the row is marked
    /// as unavailable in the UI.
    var resolvedTimeZone: TimeZone { timeZone ?? .gmt }

    var isAvailable: Bool { timeZone != nil }

    /// The name shown in the UI: the custom label when set, otherwise the
    /// localized city name from the system database.
    var title: String {
        let trimmed = customLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? TimeZoneCatalog.cityName(for: identifier) : trimmed
    }

    /// Secondary line, e.g. `Europe/Istanbul`.
    var subtitle: String { identifier }

    /// Emoji to render. Clearing the field in Settings is allowed — so the user
    /// can retype — and falls back to the region flag rather than a blank gap.
    var displaySymbol: String {
        symbol.isEmpty ? TimeZoneCatalog.suggestedSymbol(for: identifier) : symbol
    }

    /// What "already added" means in the picker.
    ///
    /// Deliberately the identifier *and* the displayed name: several places
    /// share one zone, so tracking New York must not mark Washington DC as
    /// already added. They are the same zone but not the same row.
    static func trackingKey(identifier: String, title: String) -> String {
        "\(identifier)\u{1F}\(title.lowercased())"
    }

    var trackingKey: String {
        Self.trackingKey(identifier: identifier, title: title)
    }
}

nonisolated extension TimeZoneItem {
    /// Seeded on first launch: the user's home zone plus a few common ones.
    static var starterZones: [TimeZoneItem] {
        var identifiers = ["Europe/Istanbul", "Europe/London", "America/New_York", "Asia/Tokyo"]

        // Put the user's own zone first if it is not already in the list.
        let local = TimeZone.current.identifier
        if let existing = identifiers.firstIndex(of: local) {
            identifiers.remove(at: existing)
        }
        identifiers.insert(local, at: 0)

        return identifiers.compactMap { identifier in
            TimeZone(identifier: identifier) == nil ? nil : TimeZoneItem(identifier: identifier)
        }
    }
}
