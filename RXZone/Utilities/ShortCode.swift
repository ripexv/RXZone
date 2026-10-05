//
//  ShortCode.swift
//  RXZone
//

import Foundation

/// Two- to four-letter codes for the compact menu bar style: `IST 17:00 · LON 15:00`.
///
/// Time zone abbreviations look like the obvious source and are not: macOS
/// returns `GMT+3` for most of the world, and the ones it does name change with
/// daylight saving. So codes come from the row's own name instead — initials for
/// several words (New York → NY), the first three letters for one (London →
/// LON), and a name of four letters or fewer kept whole (HQ, John → JOHN).
nonisolated enum ShortCode {

    static func code(for name: String) -> String {
        let words = normalised(name).split(separator: " ").map(String.init)
        guard !words.isEmpty else { return "" }

        let joined = words.joined()
        if joined.count <= 4 { return joined }

        // Small connecting words would otherwise turn Rio de Janeiro into RDJ.
        let significant = words.filter { !["DE", "DA", "DO", "DI", "DEL", "LA", "LE", "EL", "OF", "AND"].contains($0) }
        let initialsFrom = significant.count >= 2 ? significant : words
        if initialsFrom.count >= 2 {
            return String(initialsFrom.prefix(3).compactMap(\.first))
        }
        return String(joined.prefix(3))
    }

    /// Codes for a set of names shown side by side. Any code that would appear
    /// twice is lengthened to four letters, so two rows never read alike.
    static func codes(for names: [String]) -> [String] {
        let base = names.map(code(for:))
        var counts: [String: Int] = [:]
        for code in base { counts[code, default: 0] += 1 }

        return zip(names, base).map { name, code in
            guard counts[code, default: 0] > 1 else { return code }
            let letters = normalised(name).replacingOccurrences(of: " ", with: "")
            return String(letters.prefix(4))
        }
    }

    /// Uppercase ASCII letters and single spaces. Diacritics are folded first,
    /// and uppercasing uses a fixed locale: in Turkish, "i" uppercases to "İ",
    /// which would turn Istanbul into a code that no longer reads as IST.
    private static func normalised(_ name: String) -> String {
        name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US"))
            .uppercased(with: Locale(identifier: "en_US"))
            .unicodeScalars
            .map { CharacterSet.uppercaseLetters.contains($0) && $0.isASCII ? Character($0) : " " }
            .reduce(into: "") { $0.append($1) }
            .split(separator: " ")
            .joined(separator: " ")
    }
}
