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

@Suite("Place aliases")
struct AliasTests {

    @Test("Cities without their own zone are still findable", arguments: [
        ("las vegas", "America/Los_Angeles"),
        ("new jersey", "America/New_York"),
        ("boston", "America/New_York"),
        ("seattle", "America/Los_Angeles"),
        ("munich", "Europe/Berlin"),
        ("ankara", "Europe/Istanbul"),
        ("osaka", "Asia/Tokyo"),
        // macOS ships India under its historical identifier, though ICU still
        // displays the city as "Kolkata".
        ("mumbai", "Asia/Calcutta"),
        ("cape town", "Africa/Johannesburg"),
    ])
    func aliasFindsZone(query: String, identifier: String) {
        #expect(TimeZoneCatalog.search(query).first?.identifier == identifier,
                "\(query) should be the top result for \(identifier)")
    }

    @Test("US state names resolve to their dominant zone", arguments: [
        ("texas", "America/Chicago"),
        ("california", "America/Los_Angeles"),
        ("florida", "America/New_York"),
        ("arizona", "America/Phoenix"),
    ])
    func stateFindsZone(query: String, identifier: String) {
        #expect(TimeZoneCatalog.search(query).first?.identifier == identifier)
    }

    @Test("An alias match reports the name the user searched for")
    func aliasIsReportedBack() {
        let entry = try! #require(TimeZoneCatalog.search("las vegas").first)
        #expect(TimeZoneCatalog.matchedAlias(for: entry, query: "las vegas") == "Las Vegas")
    }

    @Test("Matching the zone's own city reports no alias")
    func cityMatchHasNoAlias() {
        let entry = try! #require(TimeZoneCatalog.search("los angeles").first)
        #expect(TimeZoneCatalog.matchedAlias(for: entry, query: "los angeles") == nil,
                "The row should stay labelled Los Angeles, not be renamed")
    }

    @Test("Alias search ignores case and diacritics")
    func aliasFolding() {
        #expect(TimeZoneCatalog.search("MÜNCHEN").first?.identifier == "Europe/Berlin")
        #expect(TimeZoneCatalog.search("izmir").first?.identifier == "Europe/Istanbul")
        #expect(TimeZoneCatalog.search("İzmir").first?.identifier == "Europe/Istanbul")
    }

    @Test("Every alias points at a zone the catalog actually lists")
    func noAliasInventsAZone() {
        // Deliberately stricter than `TimeZone(identifier:) != nil`, which also
        // accepts historical links like `Asia/Kolkata` that never appear as a
        // catalog entry and would leave the alias silently unreachable.
        let known = Set(TimeZone.knownTimeZoneIdentifiers)
        let unreachable = TimeZoneAliases.identifierByAlias.filter { !known.contains($0.value) }
        #expect(unreachable.isEmpty, "These aliases point nowhere: \(unreachable)")
    }

    @Test("Aliases never collide with a real city name in the catalog")
    func aliasesDoNotShadowRealCities() {
        let cities = Set(TimeZoneCatalog.entries.map { $0.city.lowercased() })
        let shadowed = TimeZoneAliases.identifierByAlias.keys.filter { alias in
            guard cities.contains(alias.lowercased()) else { return false }
            // Only a problem when the alias points somewhere else than the
            // real city of the same name.
            return TimeZoneCatalog.entries.first { $0.city.lowercased() == alias.lowercased() }?
                .identifier != TimeZoneAliases.identifierByAlias[alias]
        }
        #expect(shadowed.isEmpty, "These aliases hide a real zone: \(shadowed)")
    }

    @Test("Searching a country still finds the country, not a US state")
    func countryNamesWin() {
        // "Georgia" is a country as well as a US state; the country must not be
        // buried by an alias.
        #expect(TimeZoneCatalog.search("georgia").contains { $0.identifier == "Asia/Tbilisi" })
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
