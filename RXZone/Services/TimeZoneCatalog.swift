//
//  TimeZoneCatalog.swift
//  RXZone
//

import Foundation

/// The searchable list of time zones offered to the user.
///
/// Every entry originates from `TimeZone.knownTimeZoneIdentifiers`, i.e. the tz
/// database that ships with macOS. Nothing here is fetched or hard-coded, so the
/// catalog automatically follows OS updates that add or rename zones.
nonisolated enum TimeZoneCatalog {
    struct Entry: Identifiable, Hashable, Sendable {
        /// e.g. `Europe/Istanbul`
        let identifier: String
        /// Localized exemplar city, e.g. `Istanbul`
        let city: String
        /// Localized country name, e.g. `Türkiye`. Empty when unknown.
        let country: String
        /// Flag emoji, or a globe when the region is unknown.
        let symbol: String
        /// Other place names that share this zone, e.g. `Las Vegas`.
        let aliases: [String]
        /// Pre-folded haystack used for substring matching.
        let searchText: String

        var id: String { identifier }
    }

    /// Case- and diacritic-insensitive form used for every comparison.
    private static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    /// All selectable zones, sorted by their localized city name.
    static let entries: [Entry] = makeEntries()

    private static let entriesByIdentifier: [String: Entry] =
        Dictionary(entries.map { ($0.identifier, $0) }, uniquingKeysWith: { first, _ in first })

    /// Localized city name for an identifier, e.g. `Europe/Istanbul` -> `Istanbul`.
    static func cityName(for identifier: String) -> String {
        entriesByIdentifier[identifier]?.city ?? derivedCityName(for: identifier)
    }

    /// Flag emoji suggested when a zone is first added. Users can override it.
    static func suggestedSymbol(for identifier: String) -> String {
        entriesByIdentifier[identifier]?.symbol ?? Self.fallbackSymbol
    }

    static func entry(for identifier: String) -> Entry? { entriesByIdentifier[identifier] }

    /// Case- and diacritic-insensitive search across city, identifier and country.
    /// An empty query returns the whole catalog.
    static func search(_ query: String) -> [Entry] {
        let needle = fold(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !needle.isEmpty else { return entries }

        // Rank prefix matches — on the city or on an alias — above incidental
        // ones, so "lon" surfaces London before Colon, and "las v" surfaces
        // Los Angeles through "Las Vegas" instead of burying it.
        var prefixMatches: [Entry] = []
        var otherMatches: [Entry] = []
        for entry in entries where entry.searchText.contains(needle) {
            let isPrefix = fold(entry.city).hasPrefix(needle)
                || entry.aliases.contains { fold($0).hasPrefix(needle) }
            if isPrefix {
                prefixMatches.append(entry)
            } else {
                otherMatches.append(entry)
            }
        }
        return prefixMatches + otherMatches
    }

    /// The alias responsible for a match, when the query is absent from the
    /// zone's own city name.
    ///
    /// Lets the picker say "New Jersey" and explain that it shares New York's
    /// zone, rather than silently offering New York and leaving the user to
    /// guess why.
    static func matchedAlias(for entry: Entry, query: String) -> String? {
        let needle = fold(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !needle.isEmpty, !fold(entry.city).contains(needle) else { return nil }

        let folded = entry.aliases.map { (alias: $0, key: fold($0)) }
        return folded.first { $0.key.hasPrefix(needle) }?.alias
            ?? folded.first { $0.key.contains(needle) }?.alias
    }

    // MARK: - Construction

    static let fallbackSymbol = "🌐"

    private static func makeEntries() -> [Entry] {
        // `VVV` is the Unicode "exemplar city" pattern, which gives a properly
        // localized city name straight from ICU instead of a hand-made table.
        let cityFormatter = DateFormatter()
        cityFormatter.locale = .current
        cityFormatter.dateFormat = "VVV"

        let now = Date()
        let locale = Locale.current

        let entries: [Entry] = TimeZone.knownTimeZoneIdentifiers.compactMap { identifier in
            guard let timeZone = TimeZone(identifier: identifier) else { return nil }

            cityFormatter.timeZone = timeZone
            var city = cityFormatter.string(from: now)
            // ICU answers "Unknown Location" for region-less zones such as UTC.
            if city.isEmpty || city.localizedCaseInsensitiveContains("unknown") {
                city = derivedCityName(for: identifier)
            }

            // Searchable but not displayed: the area lets "europe" or "pacific"
            // narrow the list without needing a column of its own.
            let area = identifier.contains("/") ? String(identifier.split(separator: "/")[0]) : ""
            let regionCode = TimeZoneRegions.regionCodeByIdentifier[identifier]
            let country = regionCode.flatMap { locale.localizedString(forRegionCode: $0) } ?? ""
            let symbol = regionCode.flatMap { TimeZoneRegions.flagEmoji(forRegionCode: $0) } ?? fallbackSymbol

            let aliases = TimeZoneAliases.aliasesByIdentifier[identifier] ?? []
            let haystack = ([city, identifier.replacingOccurrences(of: "_", with: " "),
                             area, country, regionCode ?? ""] + aliases)
                .joined(separator: " ")
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: locale)

            return Entry(
                identifier: identifier,
                city: city,
                country: country,
                symbol: symbol,
                aliases: aliases,
                searchText: haystack
            )
        }

        return entries.sorted {
            $0.city.localizedStandardCompare($1.city) == .orderedAscending
        }
    }

    /// Last resort name built from the identifier itself, e.g.
    /// `America/Argentina/Buenos_Aires` -> `Buenos Aires`.
    private static func derivedCityName(for identifier: String) -> String {
        let last = identifier.split(separator: "/").last.map(String.init) ?? identifier
        return last.replacingOccurrences(of: "_", with: " ")
    }
}
