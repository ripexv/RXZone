//
//  TimeZoneRow.swift
//  RXZone
//

import SwiftUI

/// One zone in the popover: emoji, name, the time, and optional date/offset.
struct TimeZoneRow: View {
    let row: ZoneRow
    let date: Date
    let reference: TimeZone
    let preferences: Preferences

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(row.symbol)
                .font(.title3)
                // Emoji must not shrink when the row's text scales up.
                .frame(minWidth: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(row.title)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    // The dedicated "This Mac" row is dropped when its zone is
                    // already tracked, so mark the surviving row instead of
                    // losing the information entirely.
                    if row.isSystemZone, !row.isLocal {
                        Image(systemName: "laptopcomputer")
                            .imageScale(.small)
                            .foregroundStyle(.secondary)
                            .help(Text("This Mac’s time zone", comment: "Tooltip on the system zone row"))
                    }
                    if !row.isAvailable {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .imageScale(.small)
                    }
                }
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 1) {
                Text(timeText)
                    .monospacedDigit()
                    .fontWeight(.medium)
                if let dayLabel {
                    Text(dayLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 3)
        .opacity(row.isAvailable ? 1 : 0.5)
        .contentShape(.rect)
        // Read as a single sentence by VoiceOver instead of five fragments.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Derived text

    private var timeText: String {
        DateFormatting.timeString(
            for: date,
            in: row.timeZone,
            format: preferences.timeFormat,
            showsSeconds: preferences.showsSecondsInPopover
        )
    }

    /// Secondary line: the date, the offset from local, or both.
    private var detail: String? {
        var parts: [String] = []
        if preferences.showsDate {
            parts.append(DateFormatting.dateString(for: date, in: row.timeZone))
        }
        if preferences.showsOffsetFromLocal, !row.isLocal {
            parts.append(DateFormatting.offsetLabel(of: row.timeZone, from: reference, at: date))
        }
        if parts.isEmpty, row.isLocal { return row.subtitle }
        return parts.isEmpty ? row.subtitle : parts.joined(separator: " · ")
    }

    private var dayLabel: String? {
        guard !row.isLocal else { return nil }
        let delta = DateFormatting.dayDelta(at: date, zone: row.timeZone, reference: reference)
        return DateFormatting.dayDeltaLabel(delta)
    }

    private var accessibilityLabel: Text {
        var spoken = "\(row.title), \(timeText)"
        if let detail { spoken += ", \(detail)" }
        if let dayLabel { spoken += ", \(dayLabel)" }
        if !row.isAvailable {
            spoken += ", " + String(localized: "unavailable", comment: "Spoken for an unknown time zone")
        }
        return Text(spoken)
    }
}
