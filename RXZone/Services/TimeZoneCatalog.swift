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
        /// Area component of the identifier, e.g. `Europe`
        let area: String
        /// Localized country name, e.g. `Türkiye`. Empty when unknown.
        let country: String
        /// Flag emoji, or a globe when the region is unknown.
        let symbol: String
        /// Pre-lowercased haystack used for substring matching.
        let searchText: String

        var id: String { identifier }
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
        let needle = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        guard !needle.isEmpty else { return entries }

        // Rank exact prefix matches on the city above incidental matches so that
        // typing "lon" surfaces London before Colon or Longyearbyen.
        var prefixMatches: [Entry] = []
        var otherMatches: [Entry] = []
        for entry in entries where entry.searchText.contains(needle) {
            let city = entry.city.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            if city.hasPrefix(needle) {
                prefixMatches.append(entry)
            } else {
                otherMatches.append(entry)
            }
        }
        return prefixMatches + otherMatches
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

            let area = identifier.contains("/") ? String(identifier.split(separator: "/")[0]) : ""
            let regionCode = TimeZoneRegions.regionCodeByIdentifier[identifier]
            let country = regionCode.flatMap { locale.localizedString(forRegionCode: $0) } ?? ""
            let symbol = regionCode.flatMap { TimeZoneRegions.flagEmoji(forRegionCode: $0) } ?? fallbackSymbol

            let haystack = [city, identifier.replacingOccurrences(of: "_", with: " "), area, country, regionCode ?? ""]
                .joined(separator: " ")
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: locale)

            return Entry(
                identifier: identifier,
                city: city,
                area: area,
                country: country,
                symbol: symbol,
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
