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
    /// Called with minutes from midnight when the user types a time into this
    /// row. `nil` leaves the time read-only.
    var onSetTime: ((Int) -> Void)?

    @State private var isEditing = false
    @State private var draft = ""
    @State private var isInvalid = false
    @State private var isHoveringTime = false
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(row.symbol)
                .font(.title3)
                // Emoji must not shrink when the row's text scales up.
                .frame(minWidth: 24, minHeight: 22, alignment: .leading)
                // Badged onto the symbol rather than placed before the name:
                // it belongs to the place, and the title line stays a title.
                .overlay(alignment: .bottomTrailing) { daylightBadge }

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
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                // Present only in the week before a change, so most of the year
                // the row is exactly as it was.
                if let clockChange {
                    Text(clockChange)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 1) {
                timeView
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
        // Read as a single sentence by VoiceOver instead of five fragments —
        // except while editing, when the field itself has to be reachable.
        .accessibilityElement(children: isEditing ? .contain : .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAction(named: Text("Set a time here", comment: "Accessibility action")) {
            beginEditing()
        }
    }

    // MARK: - Typed time

    /// The clock reading, which doubles as the place to type a time. Clicking it
    /// is the shortest path from "they said 10:00" to seeing what that means
    /// everywhere else — no slider to drag in 15-minute steps.
    @ViewBuilder
    private var timeView: some View {
        if isEditing {
            TextField(text: $draft, prompt: Text(verbatim: timeText)) {
                Text("Time in \(row.title)", comment: "Accessibility label for the time field")
            }
            .textFieldStyle(.plain)
            .monospacedDigit()
            .fontWeight(.medium)
            .multilineTextAlignment(.trailing)
            .frame(width: 78)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(isInvalid ? Color.red : Color.accentColor, lineWidth: 1)
            )
            .focused($isFieldFocused)
            .onSubmit(commit)
            .onExitCommand { isEditing = false }
            .onChange(of: draft) { _, _ in isInvalid = false }
            // Clicking elsewhere abandons the edit rather than leaving a field open.
            .onChange(of: isFieldFocused) { _, focused in if !focused { isEditing = false } }
            .onAppear { isFieldFocused = true }
        } else {
            Button(action: beginEditing) {
                Text(timeText)
                    .monospacedDigit()
                    .fontWeight(.medium)
                    .padding(.horizontal, 3)
                    .background(
                        isHoveringTime && onSetTime != nil ? Color.primary.opacity(0.08) : .clear,
                        in: .rect(cornerRadius: 4)
                    )
            }
            .buttonStyle(.plain)
            .disabled(onSetTime == nil)
            .onHover { isHoveringTime = $0 }
            .help(Text("Type a time in \(row.title) to see it everywhere",
                       comment: "Tooltip on a row's time"))
        }
    }

    private func beginEditing() {
        guard onSetTime != nil, row.isAvailable else { return }
        draft = ""
        isInvalid = false
        isEditing = true
    }

    private func commit() {
        guard let minutes = TimeInput.minutes(from: draft) else {
            // Stay open and say so, rather than silently doing nothing.
            isInvalid = true
            return
        }
        onSetTime?(minutes)
        isEditing = false
    }

    /// Sun or moon, derived from the zone's own coordinates, so it needs no
    /// setting and holds at any latitude in any season. Carries a small opaque
    /// disc behind it so it stays legible over whatever emoji it sits on.
    @ViewBuilder
    private var daylightBadge: some View {
        if let isDaylight = row.isDaylight {
            Image(systemName: isDaylight ? "sun.max.fill" : "moon.fill")
                .font(.system(size: 8))
                .foregroundStyle(isDaylight ? Color.orange : Color.indigo)
                .padding(1.5)
                .background(Circle().fill(.background))
                .offset(x: 3, y: 2)
                .help(isDaylight
                      ? Text("Daytime there", comment: "Tooltip on the sun badge")
                      : Text("Night there", comment: "Tooltip on the moon badge"))
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

    /// Secondary line: the date, the offset from local, or both — falling back
    /// to the zone's own name when the user has switched both off, so the row
    /// never loses its second line entirely.
    private var detail: String {
        var parts: [String] = []
        // Only when the title is not already the city: a row renamed to "John"
        // must still say Los Angeles somewhere, but an unrenamed row should not
        // print the same word twice.
        if !row.city.isEmpty, row.title != row.city {
            parts.append(row.city)
        }
        if preferences.showsDate {
            parts.append(DateFormatting.dateString(for: date, in: row.timeZone))
        }
        if preferences.showsOffsetFromLocal, !row.isLocal {
            parts.append(DateFormatting.offsetLabel(of: row.timeZone, from: reference, at: date))
        }
        return parts.isEmpty ? row.subtitle : parts.joined(separator: " · ")
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
        var spoken = "\(row.title), \(timeText), \(detail)"
        if let isDaylight = row.isDaylight {
            spoken += ", " + (isDaylight
                ? String(localized: "daytime", comment: "Spoken status")
                : String(localized: "night", comment: "Spoken status"))
        }
        if let dayLabel { spoken += ", \(dayLabel)" }
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
