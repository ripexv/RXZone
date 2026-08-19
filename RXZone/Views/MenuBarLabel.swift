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
///
/// The string comes from `AppModel` rather than being assembled here, so the
/// Settings preview and the real menu bar always agree.
struct MenuBarLabel: View {
    let model: AppModel

    var body: some View {
        switch model.preferences.menuBarStyle {
        case .icon:
            Image(systemName: "globe")
                .accessibilityLabel(Text("RXZone time zones", comment: "Menu bar icon description"))
        case .time, .symbolAndTime, .labelAndTime:
            Text(model.menuBarText)
                .monospacedDigit()
                .accessibilityLabel(Text(model.menuBarAccessibilityText))
        }
    }
}
