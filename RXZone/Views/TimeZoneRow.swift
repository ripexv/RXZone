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
    /// Tints the row when this clock is one of the ones in the menu bar, so a
    /// glance at the panel answers "which of these am I looking at up there?"
    let isInMenuBar: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(row.symbol)
                .font(.title3)
                // Emoji must not shrink when the row's text scales up.
                .frame(minWidth: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    // Derived from the zone's own coordinates, so it needs no
                    // setting and is right at any latitude in any season.
                    if let isDaylight = row.isDaylight {
                        Image(systemName: isDaylight ? "sun.max.fill" : "moon.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(isDaylight ? Color.orange : Color.indigo)
                            .help(isDaylight
                                  ? Text("Daytime there", comment: "Tooltip on the sun icon")
                                  : Text("Night there", comment: "Tooltip on the moon icon"))
                    }

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
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
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
        .padding(.vertical, 5)
        .padding(.horizontal, 6)
        .background(
            isInMenuBar ? Color.accentColor.opacity(0.12) : .clear,
            in: .rect(cornerRadius: 6)
        )
        .opacity(row.isAvailable ? 1 : 0.5)
        .contentShape(.rect)
        .help(isInMenuBar
              ? String(localized: "Shown in the menu bar", comment: "Tooltip on a highlighted row")
              : "")
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

    /// Secondary line: the date, the offset from local, or both — falling back
    /// to the zone's own name when the user has switched both off, so the row
    /// never loses its second line entirely.
    private var detail: String {
        var parts: [String] = []
        if preferences.showsDate {
            parts.append(DateFormatting.dateString(for: date, in: row.timeZone))
        }
        if preferences.showsOffsetFromLocal, !row.isLocal {
            parts.append(DateFormatting.offsetLabel(of: row.timeZone, from: reference, at: date))
        }
        return parts.isEmpty ? row.subtitle : parts.joined(separator: " · ")
    }

    private var dayLabel: String? {
        guard !row.isLocal else { return nil }
        let delta = DateFormatting.dayDelta(at: date, zone: row.timeZone, reference: reference)
        return DateFormatting.dayDeltaLabel(delta)
    }

    private var accessibilityLabel: Text {
        var spoken = "\(row.title), \(timeText), \(detail)"
        if let isDaylight = row.isDaylight {
            spoken += ", " + (isDaylight
                ? String(localized: "daytime", comment: "Spoken status")
                : String(localized: "night", comment: "Spoken status"))
        }
        if let dayLabel { spoken += ", \(dayLabel)" }
        if isInMenuBar {
            spoken += ", " + String(localized: "shown in the menu bar",
                                    comment: "Spoken for a row mirrored into the menu bar")
        }
        if !row.isAvailable {
            spoken += ", " + String(localized: "unavailable", comment: "Spoken for an unknown time zone")
        }
        return Text(spoken)
    }
}
