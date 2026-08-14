//
//  TimeZoneCatalogTests.swift
//  RXZoneTests
//

import Testing
import Foundation
@testable import RXZone

@Suite("Catalog contents")
struct CatalogContentTests {

    @Test("The catalog mirrors the system database rather than a curated list")
    func coversTheSystemDatabase() {
        #expect(TimeZoneCatalog.entries.count == TimeZone.knownTimeZoneIdentifiers.count)
        #expect(TimeZoneCatalog.entries.count > 400)
    }

    @Test("Every entry resolves to a real time zone")
    func everyEntryIsUsable() {
        let broken = TimeZoneCatalog.entries.filter { TimeZone(identifier: $0.identifier) == nil }
        #expect(broken.isEmpty)
    }

    @Test("No entry is left without a display name")
    func everyEntryHasACity() {
        let nameless = TimeZoneCatalog.entries.filter {
            $0.city.trimmingCharacters(in: .whitespaces).isEmpty
        }
        #expect(nameless.isEmpty)
    }

    @Test("Region-less zones get a readable name instead of “Unknown Location”")
    func utcIsNamedSensibly() {
        guard let utc = TimeZoneCatalog.entry(for: "UTC") else { return }
        #expect(!utc.city.localizedCaseInsensitiveContains("unknown"))
    }

    @Test("Entries are sorted so the picker reads alphabetically")
    func sortedByCity() {
        let cities = TimeZoneCatalog.entries.map(\.city)
        #expect(cities == cities.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
    }
}

@Suite("Search")
struct CatalogSearchTests {

    @Test("An empty query returns everything")
    func emptyQuery() {
        #expect(TimeZoneCatalog.search("").count == TimeZoneCatalog.entries.count)
        #expect(TimeZoneCatalog.search("   ").count == TimeZoneCatalog.entries.count)
    }

    @Test("Searching by city finds the zone", arguments: [
        ("istanbul", "Europe/Istanbul"),
        ("tokyo", "Asia/Tokyo"),
        ("new york", "America/New_York"),
        ("auckland", "Pacific/Auckland"),
    ])
    func findsByCity(query: String, identifier: String) {
        #expect(TimeZoneCatalog.search(query).contains { $0.identifier == identifier })
    }

    @Test("Underscores in identifiers do not block a natural search")
    func underscoresAreSearchable() {
        #expect(TimeZoneCatalog.search("los angeles").contains { $0.identifier == "America/Los_Angeles" })
    }

    @Test("Searching by identifier works too")
    func findsByIdentifier() {
        #expect(TimeZoneCatalog.search("Europe/Ist").contains { $0.identifier == "Europe/Istanbul" })
    }

    @Test("Search ignores case and diacritics")
    func foldsDiacritics() {
        let plain = TimeZoneCatalog.search("zurich").map(\.identifier)
        let accented = TimeZoneCatalog.search("Zürich").map(\.identifier)
        #expect(plain == accented)
        #expect(plain.contains("Europe/Zurich"))
    }

    @Test("A city whose name starts with the query is ranked first")
    func prefixMatchesRankFirst() {
        let results = TimeZoneCatalog.search("lond")
        #expect(results.first?.identifier == "Europe/London")
    }

    @Test("Nonsense returns nothing rather than everything")
    func noMatches() {
        #expect(TimeZoneCatalog.search("zzzzzznotacity").isEmpty)
    }
}

@Suite("Region flags")
struct FlagTests {

    @Test("Well known zones get their country's flag", arguments: [
        ("Europe/Istanbul", "🇹🇷"),
        ("Europe/London", "🇬🇧"),
        ("America/New_York", "🇺🇸"),
        ("Asia/Tokyo", "🇯🇵"),
        ("Australia/Sydney", "🇦🇺"),
    ])
    func knownFlags(identifier: String, flag: String) {
        #expect(TimeZoneCatalog.suggestedSymbol(for: identifier) == flag)
    }

    @Test("An unmapped identifier falls back to a neutral globe")
    func unknownFallsBack() {
        #expect(TimeZoneCatalog.suggestedSymbol(for: "Mars/Olympus_Mons") == TimeZoneCatalog.fallbackSymbol)
    }

    @Test("Region codes convert to regional indicator pairs")
    func flagConversion() {
        #expect(TimeZoneRegions.flagEmoji(forRegionCode: "TR") == "🇹🇷")
        #expect(TimeZoneRegions.flagEmoji(forRegionCode: "us") == "🇺🇸", "Lower case should still work")
    }

    @Test("Malformed region codes are rejected", arguments: ["", "X", "XYZ", "12", "T1"])
    func rejectsMalformedCodes(code: String) {
        #expect(TimeZoneRegions.flagEmoji(forRegionCode: code) == nil)
    }

    @Test("Nearly every zone in the database maps to a region")
    func coverageIsHigh() {
        let mapped = TimeZone.knownTimeZoneIdentifiers.filter {
            TimeZoneRegions.regionCodeByIdentifier[$0] != nil
        }
        // Only region-less zones such as bare GMT are expected to be missing.
        #expect(mapped.count >= TimeZone.knownTimeZoneIdentifiers.count - 3)
    }
}
