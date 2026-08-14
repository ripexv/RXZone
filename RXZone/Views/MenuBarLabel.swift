//
//  MenuBarLabel.swift
//  RXZone
//

import SwiftUI

/// The status item itself.
///
/// Kept to a single `Text` or `Image`, which is what `MenuBarExtra` renders
/// most predictably. Digits are monospaced so the menu bar does not shift
/// width every minute.
struct MenuBarLabel: View {
    let model: AppModel

    var body: some View {
        switch model.preferences.menuBarStyle {
        case .icon:
            Image(systemName: "globe")
                .accessibilityLabel(Text("RXZone time zones", comment: "Menu bar icon description"))
        case .time, .symbolAndTime, .labelAndTime:
            Text(title)
                .monospacedDigit()
                .accessibilityLabel(accessibilityLabel)
        }
    }

    private func timeText(for row: ZoneRow) -> String {
        DateFormatting.timeString(
            for: model.displayDate,
            in: row.timeZone,
            format: model.preferences.timeFormat,
            showsSeconds: model.preferences.menuBarShowsSeconds
        )
    }

    /// One clock per selected zone, joined with a thin gap so several fit
    /// without reading as a single run-on string.
    private var title: String {
        // A leading marker makes an active time travel offset obvious even when
        // the popover is closed.
        let prefix = model.isTimeTravelling ? "⏱ " : ""
        return prefix + model.menuBarRows.map(clock(for:)).joined(separator: "   ")
    }

    private func clock(for row: ZoneRow) -> String {
        let time = timeText(for: row)
        return switch model.preferences.menuBarStyle {
        case .icon: ""
        case .time: time
        case .symbolAndTime: "\(row.symbol) \(time)"
        case .labelAndTime: "\(row.title) \(time)"
        }
    }

    private var accessibilityLabel: Text {
        let spoken = model.menuBarRows
            .map { "\($0.title) \(timeText(for: $0))" }
            .joined(separator: ", ")
        return Text(spoken)
    }
}
