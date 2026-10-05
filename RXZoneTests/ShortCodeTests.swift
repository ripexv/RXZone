//
//  ShortCodeTests.swift
//  RXZoneTests
//

import Testing
import Foundation
@testable import RXZone

@Suite("Short codes")
struct ShortCodeTests {

    @Test("Codes read the way people abbreviate cities", arguments: [
        ("Istanbul", "IST"), ("London", "LON"), ("Tokyo", "TOK"), ("Warsaw", "WAR"),
        ("New York", "NY"), ("Los Angeles", "LA"), ("Salt Lake City", "SLC"),
        ("Rio de Janeiro", "RJ"), ("HQ", "HQ"), ("John", "JOHN"), ("Ana", "ANA"),
    ] as [(String, String)])
    func codes(name: String, expected: String) {
        #expect(ShortCode.code(for: name) == expected)
    }

    @Test("Diacritics and the Turkish dotted İ do not leak into the code", arguments: [
        ("İstanbul", "IST"), ("İzmir", "IZM"), ("Zürich", "ZUR"), ("São Paulo", "SP"), ("Kraków", "KRA"),
    ] as [(String, String)])
    func folding(name: String, expected: String) {
        #expect(ShortCode.code(for: name) == expected)
    }

    @Test("Codes that would collide are lengthened so rows stay distinct")
    func collisions() {
        let codes = ShortCode.codes(for: ["Santiago", "Santo Domingo", "Sanaa"])
        #expect(Set(codes).count == codes.count, "Got \(codes)")
    }

    @Test("Codes that do not collide are left short")
    func noCollision() {
        #expect(ShortCode.codes(for: ["Istanbul", "London", "New York"]) == ["IST", "LON", "NY"])
    }

    @Test("Punctuation and digits are ignored rather than printed")
    func punctuation() {
        #expect(ShortCode.code(for: "St. Louis") == "SL")
        #expect(ShortCode.code(for: "Office #2") == "OFF")
    }

    @Test("A name with no letters at all yields nothing rather than garbage")
    func empty() {
        #expect(ShortCode.code(for: "") == "")
        #expect(ShortCode.code(for: "123") == "")
    }
}

@Suite("Short code menu bar")
struct ShortCodeMenuBarTests {

    @Test("The menu bar reads code, time, separated by a dot")
    func menuBarText() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let model = AppModel(defaults: defaults)

        model.preferences.zones = []
        model.addZone(identifier: "America/New_York")
        model.addZone(identifier: "Europe/London")
        model.setShowsInMenuBar(false, for: ZoneRow.localRowID)
        model.preferences.menuBarStyle = .codeAndTime

        let text = model.menuBarText
        #expect(text.hasPrefix("NY "), "Got \(text)")
        #expect(text.contains(" · LON "), "Got \(text)")
    }

    @Test("A renamed row is coded by its new name, the local row by its city")
    func codeSources() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let model = AppModel(defaults: defaults)

        model.preferences.zones = []
        model.addZone(identifier: "America/Los_Angeles", customLabel: "John")
        model.preferences.menuBarStyle = .codeAndTime

        let text = model.menuBarText
        #expect(text.contains("JOHN "), "Got \(text)")
        #expect(!text.contains("TM "), "\"This Mac\" must never become a code")
    }
}
