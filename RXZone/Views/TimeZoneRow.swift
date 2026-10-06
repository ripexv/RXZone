//
//  TimeZoneRow.swift
//  RXZone
//

import SwiftUI

/// One zone in the popover. Who and where on the left, when on the right.
struct TimeZoneRow: View {
    let row: ZoneRow
    let date: Date
    let reference: TimeZone
    let preferences: Preferences
    /// Tints the row when this clock is one of the ones in the menu bar, so a
    /// glance at the panel answers "which of these am I looking at up there?"
    let isInMenuBar: Bool
    /// Called with minutes from midnight when the user types a time into this
    /// row. `nil` leaves the time read-only.
    var onSetTime: ((Int) -> Void)?

    @State private var isEditing = false
    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZoneAvatar(row: row, size: PanelMetrics.avatar)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(row.title)
                        .font(.system(size: PanelMetrics.title, weight: .semibold))
                        .lineLimit(1)
                    // The "This Mac" header is dropped when its zone is already
                    // tracked, so mark the surviving row instead of losing the
                    // information entirely.
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
                Text(location)
                    .font(.system(size: PanelMetrics.body))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                // Present only in the week before a change, so most of the year
                // the row is exactly as it was.
                if let clockChange {
                    Text(clockChange)
                        .font(.system(size: PanelMetrics.note, weight: .medium))
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 1) {
                EditableTime(
                    text: timeText,
                    font: .system(size: PanelMetrics.title, weight: .medium, design: .monospaced),
                    placeName: row.title,
                    onSetTime: row.isAvailable ? onSetTime : nil,
                    isEditing: $isEditing
                )
                if let timeDetail {
                    Text(timeDetail)
                        .font(.system(size: PanelMetrics.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, PanelMetrics.edge - PanelMetrics.listInset)
        .background { rowBackground }
        .opacity(row.isAvailable ? 1 : 0.5)
        .contentShape(.rect)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .help(isInMenuBar
              ? String(localized: "Shown in the menu bar", comment: "Tooltip on a highlighted row")
              : "")
        // Read as a single sentence by VoiceOver instead of five fragments —
        // except while editing, when the field itself has to be reachable.
        .accessibilityElement(children: isEditing ? .contain : .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAction(named: Text("Set a time here", comment: "Accessibility action")) {
            if onSetTime != nil, row.isAvailable { isEditing = true }
        }
    }

    /// The hovered row lifts into a card — the panel's own colour behind it,
    /// a soft shadow under it — the way the rest of macOS raises the item
    /// under the pointer. A row shown in the menu bar keeps its accent tint
    /// underneath, so lifting it never hides that.
    @ViewBuilder
    private var rowBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        ZStack {
            if isInMenuBar {
                shape.fill(Color.accentColor.opacity(0.10))
            }
            if isHovering {
                shape.fill(.background)
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 1)
                if isInMenuBar {
                    shape.fill(Color.accentColor.opacity(0.06))
                }
            }
        }
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

    /// Under the name: where the row is, plus the full date when the user
    /// has asked for it in Settings.
    private var location: String {
        guard preferences.showsDate else { return row.location }
        return row.location + " · " + DateFormatting.dateString(for: date, in: row.timeZone)
    }

    /// Under the time: how far it is from yours, led by the day when the zone
    /// sits on a different one — "Tomorrow · +9h". The day is the part people
    /// get wrong, so it is kept even when the offset is switched off.
    private var timeDetail: String? {
        if row.isLocal {
            return String(localized: "Local time", comment: "Under the time on the row for this Mac")
        }
        var parts: [String] = []
        if let dayLabel { parts.append(dayLabel) }
        if preferences.showsOffsetFromLocal {
            parts.append(DateFormatting.offsetLabel(of: row.timeZone, from: reference, at: date))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var clockChange: String? {
        DateFormatting.clockChangeNotice(for: row.timeZone, reference: reference, at: date)
    }

    private var dayLabel: String? {
        guard !row.isLocal else { return nil }
        let delta = DateFormatting.dayDelta(at: date, zone: row.timeZone, reference: reference)
        return DateFormatting.dayDeltaLabel(delta)
    }

    private var accessibilityLabel: Text {
        var spoken = "\(row.title), \(location), \(timeText)"
        if let timeDetail { spoken += ", \(timeDetail)" }
        if let isDaylight = row.isDaylight {
            spoken += ", " + (isDaylight
                ? String(localized: "daytime", comment: "Spoken status")
                : String(localized: "night", comment: "Spoken status"))
        }
        if let clockChange { spoken += ", \(clockChange)" }
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

/// The row's emoji on its disc, set against the sky it has right now.
struct ZoneAvatar: View {
    let row: ZoneRow
    let size: CGFloat

    var body: some View {
        EmojiDisc(symbol: row.symbol, size: size, sky: SkyScene(isDaylight: row.isDaylight))
            .help(helpText)
    }

    /// Derived from the zone's own coordinates, so it holds at any latitude in
    /// any season. No tooltip when the zone has no coordinates to reason from.
    private var helpText: Text {
        switch row.isDaylight {
        case true?: Text("Daytime there", comment: "Tooltip on the sun badge")
        case false?: Text("Night there", comment: "Tooltip on the moon badge")
        case nil: Text(verbatim: "")
        }
    }
}
