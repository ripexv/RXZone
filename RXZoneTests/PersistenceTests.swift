//
//  PersistenceTests.swift
//  RXZoneTests
//

import Testing
import Foundation
@testable import RXZone

private func decode(_ json: String) throws -> Preferences {
    try JSONDecoder().decode(Preferences.self, from: Data(json.utf8))
}

@Suite("Preferences decoding")
struct PreferencesDecodingTests {

    @Test("An empty object yields a complete default configuration")
    func emptyObject() throws {
        let preferences = try decode("{}")
        #expect(preferences.timeFormat == .system)
        #expect(preferences.showsLocalZone)
        #expect(!preferences.showsTimeTravel)
        #expect(preferences.travelStep == .quarterHour)
        #expect(!preferences.zones.isEmpty, "A first launch should seed starter zones")
    }

    @Test("Keys that are present win; the rest fall back")
    func partialPayload() throws {
        let preferences = try decode(#"{"timeFormat":"twelveHour","showsDate":false}"#)
        #expect(preferences.timeFormat == .twelveHour)
        #expect(preferences.showsDate == false)
        // Untouched keys keep their defaults rather than being zeroed out.
        #expect(preferences.showsOffsetFromLocal)
        #expect(preferences.travelStep == .quarterHour)
    }

    @Test("An unrecognised enum value falls back instead of throwing")
    func unknownEnumCase() throws {
        let preferences = try decode(#"{"timeFormat":"quantum","menuBarStyle":"hologram"}"#)
        #expect(preferences.timeFormat == .system)
        #expect(preferences.menuBarStyle == .symbolAndTime)
    }

    @Test("A deliberately emptied zone list stays empty")
    func emptyZoneListIsHonoured() throws {
        let preferences = try decode(#"{"zones":[]}"#)
        #expect(preferences.zones.isEmpty, "Clearing every zone must not re-seed the starters")
    }

    @Test("A full round trip preserves every field")
    func roundTrip() throws {
        var original = Preferences()
        original.timeFormat = .twentyFourHour
        original.showsTimeTravel = true
        original.travelStep = .hour
        original.menuBarStyle = .labelAndTime
        original.showsSecondsInPopover = true
        original.zones = [TimeZoneItem(identifier: "Asia/Tokyo", customLabel: "HQ", symbol: "🗼")]
        original.menuBarZoneIDs = [original.zones[0].id]

        let restored = try JSONDecoder().decode(
            Preferences.self, from: JSONEncoder().encode(original))
        #expect(restored == original)
    }

    @Test("Malformed JSON throws so the caller can fall back")
    func corruptPayloadThrows() {
        #expect(throws: (any Error).self) { try decode("not json at all") }
    }
}

@Suite("Time zone items")
struct TimeZoneItemTests {

    @Test("A pasted essay is clamped to two glyphs")
    func longSymbolIsClamped() {
        var item = TimeZoneItem(identifier: "Europe/Istanbul")
        item.symbol = "this is far too long to sit in a menu bar"
        #expect(item.symbol.count == 2)
    }

    @Test("A flag counts as one glyph, not two scalars")
    func flagSurvivesIntact() {
        var item = TimeZoneItem(identifier: "Europe/Istanbul")
        item.symbol = "🇹🇷"
        #expect(item.symbol == "🇹🇷")
    }

    @Test("Two flags are allowed; a third is dropped")
    func twoGlyphLimit() {
        var item = TimeZoneItem(identifier: "Europe/Istanbul")
        item.symbol = "🇹🇷🇬🇧🇺🇸"
        #expect(item.symbol == "🇹🇷🇬🇧")
    }

    @Test("Whitespace and newlines are stripped")
    func whitespaceIsTrimmed() {
        var item = TimeZoneItem(identifier: "Europe/Istanbul")
        item.symbol = "  \n🇹🇷\n  "
        #expect(item.symbol == "🇹🇷")
    }

    @Test("An oversized stored symbol is clamped on decode too")
    func decodingClamps() throws {
        let json = #"{"identifier":"Europe/Istanbul","symbol":"aaaaaaaaaaaaaaa","customLabel":""}"#
        let item = try JSONDecoder().decode(TimeZoneItem.self, from: Data(json.utf8))
        #expect(item.symbol.count == 2)
    }

    @Test("Clearing the symbol falls back to the region flag for display")
    func clearedSymbolFallsBack() {
        var item = TimeZoneItem(identifier: "Europe/Istanbul")
        item.symbol = ""
        #expect(item.symbol.isEmpty, "Storage stays empty so the field can be retyped")
        #expect(item.displaySymbol == "🇹🇷")
    }

    @Test("A custom label overrides the city name; blank falls back")
    func labelFallback() {
        var item = TimeZoneItem(identifier: "Asia/Tokyo", customLabel: "Head Office")
        #expect(item.title == "Head Office")
        item.customLabel = "   "
        #expect(item.title != "   ", "A whitespace-only label should not be used")
    }

    @Test("An identifier this Mac does not know degrades safely")
    func unknownIdentifierDoesNotTrap() {
        let item = TimeZoneItem(identifier: "Mars/Olympus_Mons")
        #expect(item.timeZone == nil)
        #expect(!item.isAvailable)
        #expect(item.resolvedTimeZone == .gmt)
        #expect(item.displaySymbol == TimeZoneCatalog.fallbackSymbol)
    }

    @Test("Decoding without an id still produces a usable item")
    func missingIDIsGenerated() throws {
        let item = try JSONDecoder().decode(
            TimeZoneItem.self, from: Data(#"{"identifier":"Asia/Tokyo"}"#.utf8))
        #expect(item.identifier == "Asia/Tokyo")
        #expect(item.symbol == "🇯🇵")
    }
}
