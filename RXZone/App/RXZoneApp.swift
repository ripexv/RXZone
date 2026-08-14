//
//  RXZoneApp.swift
//  RXZone
//
//  A menu bar utility that tracks several time zones at once.
//  Everything is computed locally from Foundation's time zone database:
//  the app makes no network requests and ships without a network entitlement.
//

import SwiftUI

@main
struct RXZoneApp: App {
    /// Single owner of all app state; both scenes read from it.
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(model)
        } label: {
            MenuBarLabel(model: model)
        }
        // `.window` gives us a real SwiftUI panel rather than an NSMenu, which
        // is what lets the popover host a slider and a search field.
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(model)
        }
        .defaultSize(width: 520, height: 420)
    }
}
