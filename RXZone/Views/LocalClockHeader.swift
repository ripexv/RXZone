//
//  LocalClockHeader.swift
//  RXZone
//

import SwiftUI

/// This Mac's own time, set large at the top of the panel.
///
/// It is the clock every other row is measured against, so it reads as the
/// anchor rather than as one more entry in the list — and the list below it is
/// one row shorter for it.
struct LocalClockHeader: View {
    let row: ZoneRow
    let date: Date
    let preferences: Preferences
    let isInMenuBar: Bool
    var onSetTime: ((Int) -> Void)?

    @State private var isEditing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                if let isDaylight = row.isDaylight {
                    Image(systemName: isDaylight ? "sun.max.fill" : "moon.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(isDaylight ? Color.orange : Color.indigo)
                        .help(isDaylight
                              ? Text("Daytime there", comment: "Tooltip on the sun badge")
                              : Text("Night there", comment: "Tooltip on the moon badge"))
                }
                Text(verbatim: "\(dateText) · \(row.city)")
                    .lineLimit(1)
                Spacer(minLength: 0)
                if isInMenuBar {
                    Image(systemName: "menubar.rectangle")
                        .imageScale(.small)
                        .help(Text("Shown in the menu bar", comment: "Tooltip on a highlighted row"))
                }
            }
            .font(.system(size: PanelMetrics.body, weight: .medium))
            .foregroundStyle(.secondary)

            EditableTime(
                text: timeText,
                font: .system(size: PanelMetrics.headerTime, weight: .medium, design: .monospaced),
                placeName: row.city,
                fieldWidth: 150,
                onSetTime: onSetTime,
                isEditing: $isEditing
            )
            // The resting time sits flush left like the date above it; the
            // editing field keeps its own trailing alignment inside its frame.
            .padding(.leading, -3)

            if let clockChange {
                Text(clockChange)
                    .font(.system(size: PanelMetrics.note, weight: .medium))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, PanelMetrics.edge)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: isEditing ? .contain : .ignore)
        .accessibilityLabel(Text(verbatim: "\(row.title), \(row.city), \(timeText), \(dateText)"))
        .accessibilityAction(named: Text("Set a time here", comment: "Accessibility action")) {
            if onSetTime != nil { isEditing = true }
        }
    }

    private var timeText: String {
        DateFormatting.timeString(
            for: date,
            in: row.timeZone,
            format: preferences.timeFormat,
            showsSeconds: preferences.showsSecondsInPopover
        )
    }

    /// Always shown here, whatever the date setting says: the header is the
    /// one place the full date belongs.
    private var dateText: String {
        DateFormatting.dateString(for: date, in: row.timeZone)
    }

    /// Measured against itself, so only the change is announced — there is no
    /// gap to a reference when this is the reference.
    private var clockChange: String? {
        DateFormatting.clockChangeNotice(for: row.timeZone, reference: row.timeZone, at: date)
    }
}
