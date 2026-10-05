//
//  TimeInput.swift
//  RXZone
//

import Foundation

/// Reads a wall-clock time the way people actually type one.
///
/// `10`, `10:30`, `10.30`, `1030`, `930`, `10am`, `10:30 pm`, `22h15` — all
/// of these turn up when someone copies a time out of a message, so the parser
/// accepts the lot rather than insisting on one format and rejecting the rest.
nonisolated enum TimeInput {

    /// Minutes from midnight, or `nil` when the text is not a valid time.
    static func minutes(from raw: String) -> Int? {
        var text = raw.lowercased().trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }

        // Longest suffixes first, so "a.m." is not read as "a" followed by junk.
        var meridiem: Int?
        for (suffix, offset) in [("a.m.", 0), ("p.m.", 12), ("am", 0), ("pm", 12), ("a", 0), ("p", 12)]
        where text.hasSuffix(suffix) {
            meridiem = offset
            text = String(text.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
            break
        }

        let parts = text.split(whereSeparator: { ":.h ".contains($0) }).map(String.init)
        guard parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isASCIIDigit) }) else { return nil }

        let hour: Int, minute: Int
        switch parts.count {
        case 1:
            let digits = parts[0]
            switch digits.count {
            case 1, 2: hour = Int(digits)!; minute = 0
            // "930" and "1030": the last two digits are the minutes.
            case 3, 4: hour = Int(digits.dropLast(2))!; minute = Int(digits.suffix(2))!
            default: return nil
            }
        case 2:
            // "10:5" is more likely a typo than five past ten, so insist on two.
            guard parts[1].count == 2 else { return nil }
            hour = Int(parts[0])!
            minute = Int(parts[1])!
        default:
            return nil
        }

        guard (0...59).contains(minute) else { return nil }

        if let meridiem {
            guard (1...12).contains(hour) else { return nil }
            return ((hour % 12) + meridiem) * 60 + minute
        }
        guard (0...23).contains(hour) else { return nil }
        return hour * 60 + minute
    }
}

private nonisolated extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}
