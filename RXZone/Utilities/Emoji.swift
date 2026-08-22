//
//  Emoji.swift
//  RXZone
//

import Foundation

nonisolated extension Character {

    /// True only for characters that actually render as emoji.
    ///
    /// `isEmoji` on its own is far too generous: it is set for plain digits and
    /// `#`, because those can begin keycap sequences, so a check built on it
    /// happily accepts `1` as a flag. Flags are their own case again — a pair of
    /// regional indicators carries no emoji-presentation property of its own.
    var isEmojiGlyph: Bool {
        guard let first = unicodeScalars.first else { return false }

        let isFlag = unicodeScalars.count == 2
            && unicodeScalars.allSatisfy { (0x1F1E6...0x1F1FF).contains($0.value) }

        return isFlag
            || first.properties.isEmojiPresentation
            // Emoji that default to text presentation, such as ☀️ or ❤️, are
            // followed by a variation selector.
            || (first.properties.isEmoji && unicodeScalars.count > 1)
    }
}

nonisolated enum EmojiSuggestions {

    /// Offered in the picker, ahead of anything the user pastes themselves.
    /// Chosen for what people actually label a clock with: where it is, who is
    /// there, and what time of day it stands for.
    static let all: [String] = [
        "🏠", "🏢", "💻", "🛏️", "🏝️", "🏫", "🏥", "🚀",
        "☀️", "🌙", "⏰", "🌅", "🌃", "⭐️", "🔥", "⚡️",
        "👤", "👥", "🧑‍💻", "👨‍👩‍👧", "🤝", "💬", "📞", "📍",
        "🌍", "🌎", "🌏", "✈️", "🚂", "⛵️", "☕️", "🎯",
    ]
}
