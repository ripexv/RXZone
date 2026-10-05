//
//  LocalizationTests.swift
//  RXZoneTests
//

import Testing
import Foundation
@testable import RXZone

/// The Turkish strings as they ship, read out of the built app bundle rather
/// than the source catalog, so a translation that never made it into the
/// product fails here.
private let turkish: [String: String] = {
    guard let path = Bundle.main.path(forResource: "tr", ofType: "lproj"),
          let table = NSDictionary(contentsOfFile: path + "/Localizable.strings") as? [String: String]
    else { return [:] }
    return table
}()

/// `%@`, `%lld`, `%2$@` … reduced to their types, in order of argument position.
private func specifiers(_ text: String) -> [String] {
    let pattern = try! NSRegularExpression(pattern: "%(?:(\\d+)\\$)?(lld|ld|d|@|f)")
    let matches = pattern.matches(in: text, range: NSRange(text.startIndex..., in: text))
    var positional: [(Int, String)] = []
    for (index, match) in matches.enumerated() {
        let position = Range(match.range(at: 1), in: text).flatMap { Int(text[$0]) } ?? index + 1
        positional.append((position, String(text[Range(match.range(at: 2), in: text)!])))
    }
    return positional.sorted { $0.0 < $1.0 }.map(\.1)
}

@Suite("Turkish localization")
struct LocalizationTests {

    @Test("The Turkish table ships inside the app")
    func shipped() {
        #expect(turkish.count > 100, "Found only \(turkish.count) Turkish strings in the bundle")
        #expect(turkish["Copy All Times"] == "Tüm Saatleri Kopyala")
    }

    @Test("No translation drops, adds or retypes a format argument")
    func argumentsMatch() {
        let broken = turkish.filter { specifiers($0.key) != specifiers($0.value) }
        #expect(broken.isEmpty, "These would crash or print the wrong value: \(broken)")
    }

    @Test("Reordered arguments still use each one exactly once")
    func positionalArguments() throws {
        let dst = try #require(turkish["Clocks go back %@ %@"])
        #expect(dst.contains("%1$@") && dst.contains("%2$@"))
        let pin = try #require(turkish["%@ in %@ · %@"])
        #expect(pin.contains("%1$@") && pin.contains("%2$@") && pin.contains("%3$@"))
    }
}

@Suite("App language")
struct AppLanguageTests {

    @Test("Choosing a language swaps the language and keeps the region")
    func keepsRegion() {
        let locale = AppLanguage.locale(for: .turkish, region: Locale(identifier: "en_US"))
        #expect(locale.language.languageCode?.identifier == "tr")
        #expect(locale.region?.identifier == "US")
    }

    @Test("Dates follow the chosen language, not just the interface strings")
    func datesFollowLanguage() {
        let locale = AppLanguage.locale(for: .turkish, region: Locale(identifier: "en_US"))
        let sunday = Date(timeIntervalSince1970: 1_792_929_600)   // Sunday 25 Oct 2026, 12:00 UTC
        let text = sunday.formatted(Date.FormatStyle(locale: locale, timeZone: .gmt).weekday(.wide))
        #expect(text == "Pazar", "Got \(text) — the interface would read Turkish beside an English weekday")
    }

    @Test("System leaves the Mac's own locale untouched")
    func systemIsPassThrough() {
        let base = Locale(identifier: "de_CH")
        #expect(AppLanguage.locale(for: .system, region: base) == base)
    }
}
