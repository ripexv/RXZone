//
//  SettingsView.swift
//  RXZone
//

import SwiftUI

/// Native Settings window, opened from the popover's gear button or ⌘,
struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TabView {
            Tab {
                GeneralSettingsView(model: model)
            } label: {
                Label {
                    Text("General", comment: "Settings tab")
                } icon: {
                    Image(systemName: "gearshape")
                }
            }

            Tab {
                TimeZoneSettingsView(model: model)
            } label: {
                Label {
                    Text("Time Zones", comment: "Settings tab")
                } icon: {
                    Image(systemName: "globe")
                }
            }

            Tab {
                MenuBarSettingsView(model: model)
            } label: {
                Label {
                    Text("Menu Bar", comment: "Settings tab")
                } icon: {
                    Image(systemName: "menubar.rectangle")
                }
            }

            Tab {
                TimeTravelSettingsView(model: model)
            } label: {
                Label {
                    Text("Time Travel", comment: "Settings tab")
                } icon: {
                    Image(systemName: "clock.arrow.2.circlepath")
                }
            }
        }
        .frame(width: 520, height: 420)
    }
}

// MARK: - General

private struct GeneralSettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section {
                Picker(selection: $model.preferences.timeFormat) {
                    ForEach(TimeFormat.allCases) { format in
                        Text(format.label).tag(format)
                    }
                } label: {
                    Text("Time format", comment: "Setting label")
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("“System” follows the 24-hour setting in System Settings › General › Date & Time.",
                     comment: "Explains the system time format option")
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section {
                Toggle(isOn: $model.preferences.showsLocalZone) {
                    Text("Show this Mac’s time zone", comment: "Setting label")
                }
                Toggle(isOn: $model.preferences.showsDate) {
                    Text("Show weekday and date", comment: "Setting label")
                }
                Toggle(isOn: $model.preferences.showsOffsetFromLocal) {
                    Text("Show offset from local time", comment: "Setting label")
                }
                Toggle(isOn: $model.preferences.showsSecondsInPopover) {
                    Text("Show seconds", comment: "Setting label")
                }
            } header: {
                Text("Popover", comment: "Settings section title")
            } footer: {
                Text("macOS already shows local time in its own clock, so this row is optional. It reappears while time travelling, because the system clock does not move with the slider. It is also hidden automatically when this Mac’s zone is already in your list.",
                     comment: "Explains when the local row is shown")
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section {
                Toggle(isOn: launchAtLoginBinding) {
                    Text("Open RXZone at login", comment: "Setting label")
                }
                if let failure = model.launchAtLogin.failureMessage {
                    Text(failure)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Startup", comment: "Settings section title")
            }

            Section {
                Button(role: .destructive) {
                    model.resetToDefaults()
                } label: {
                    Text("Reset All Settings", comment: "Button")
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { model.launchAtLogin.refresh() }
    }

    /// Reads the real login-item status back from the system after every write,
    /// so a rejected registration does not leave the switch lying.
    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { model.launchAtLogin.isEnabled },
            set: { model.launchAtLogin.setEnabled($0) }
        )
    }
}

// MARK: - Time Zones

private struct TimeZoneSettingsView: View {
    @Bindable var model: AppModel
    @State private var selection: UUID?
    @State private var isAdding = false

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(model.preferences.zones) { item in
                    row(for: item)
                }
                .onMove { model.moveZones(fromOffsets: $0, toOffset: $1) }
                .onDelete { model.removeZones(atOffsets: $0) }
            }
            .listStyle(.inset)
            .onDeleteCommand(perform: deleteSelection)
            .overlay {
                if model.preferences.zones.isEmpty {
                    Text("No time zones added yet.", comment: "Empty list message")
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack(spacing: 6) {
                Button(action: { isAdding = true }) {
                    Image(systemName: "plus")
                }
                .help(Text("Add a time zone", comment: "Tooltip"))
                .accessibilityLabel(Text("Add a time zone", comment: "Button"))

                Button(action: deleteSelection) {
                    Image(systemName: "minus")
                }
                .disabled(selection == nil)
                .help(Text("Remove the selected time zone", comment: "Tooltip"))
                .accessibilityLabel(Text("Remove time zone", comment: "Button"))

                Spacer()

                Text("Drag to reorder. Leave a name empty to use the city name.",
                     comment: "Hint under the time zone list")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .sheet(isPresented: $isAdding) {
            AddTimeZoneView(
                trackedKeys: model.trackedKeys,
                referenceDate: model.displayDate,
                timeFormat: model.preferences.timeFormat,
                onSelect: { model.addZone(identifier: $0, customLabel: $1 ?? "") },
                onClose: { isAdding = false }
            )
            .frame(width: 360)
        }
    }

    private func row(for item: TimeZoneItem) -> some View {
        let binding = binding(for: item)

        return HStack(spacing: 10) {
            TextField(
                text: binding.symbol,
                prompt: Text(verbatim: TimeZoneCatalog.fallbackSymbol)
            ) {
                Text("Emoji", comment: "Field label for the row emoji")
            }
            .labelsHidden()
            .frame(width: 52)
            .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 2) {
                TextField(
                    text: binding.customLabel,
                    prompt: Text(TimeZoneCatalog.cityName(for: item.identifier))
                ) {
                    Text("Name", comment: "Field label for the custom zone name")
                }
                .labelsHidden()
                .textFieldStyle(.plain)
                .fontWeight(.medium)

                Text(item.identifier)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(DateFormatting.timeString(
                for: model.displayDate,
                in: item.resolvedTimeZone,
                format: model.preferences.timeFormat))
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .tag(item.id)
    }

    /// Looks the item up by identity on every access so the binding stays valid
    /// even if the list is reordered or shortened while a field is focused.
    private func binding(for item: TimeZoneItem) -> Binding<TimeZoneItem> {
        Binding(
            get: { model.preferences.zones.first { $0.id == item.id } ?? item },
            set: { model.updateZone($0) }
        )
    }

    private func deleteSelection() {
        guard let selection else { return }
        model.removeZone(id: selection)
        self.selection = nil
    }
}

// MARK: - Menu Bar

private struct MenuBarSettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section {
                Picker(selection: $model.preferences.menuBarStyle) {
                    ForEach(MenuBarStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                } label: {
                    Text("Show", comment: "Setting label for menu bar appearance")
                }

                Toggle(isOn: $model.preferences.menuBarShowsSeconds) {
                    Text("Show seconds", comment: "Setting label")
                }
                .disabled(!model.preferences.menuBarStyle.showsTime)
            } header: {
                Text("Menu Bar Item", comment: "Settings section title")
            } footer: {
                Text("Showing seconds updates the clock once a second instead of once a minute.",
                     comment: "Explains the power cost of showing seconds")
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section {
                // Labelled by what it does, not by the city it happens to
                // resolve to — otherwise it reads like a zone the user added.
                menuBarToggle(
                    id: ZoneRow.localRowID,
                    title: String(localized: "This Mac’s time zone",
                                  comment: "Menu bar toggle for the local clock"),
                    subtitle: "\(model.localRow.symbol) \(model.localRow.subtitle)")

                ForEach(model.preferences.zones) { item in
                    menuBarToggle(id: item.id, title: "\(item.displaySymbol) \(item.title)")
                }
            } header: {
                Text("Show in Menu Bar", comment: "Settings section title")
            } footer: {
                Text("New time zones are added here automatically. Untick any you would rather keep in the popover only — or right-click the row in the popover.",
                     comment: "Explains multi-zone menu bar selection")
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section {
                Picker(selection: $model.preferences.globalShortcut) {
                    ForEach(ShortcutPreset.allCases) { preset in
                        Text(preset.label).tag(preset)
                    }
                } label: {
                    Text("Toggle shortcut", comment: "Setting label for the global keyboard shortcut")
                }

                if model.preferences.globalShortcut != .off, !model.shortcuts.isRegistered {
                    Label {
                        Text("Another app is already using this shortcut.",
                             comment: "Shown when the hot key could not be claimed")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            } header: {
                Text("Keyboard", comment: "Settings section title")
            } footer: {
                Text("Opens and closes the popover from anywhere. If another app already owns the combination, RXZone leaves it alone.",
                     comment: "Explains global shortcut behaviour")
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent {
                    Text(preview).monospacedDigit()
                } label: {
                    Text("Preview", comment: "Setting label")
                }
            }
        }
        .formStyle(.grouped)
    }

    private func menuBarToggle(id: UUID, title: String, subtitle: String? = nil) -> some View {
        Toggle(isOn: Binding(
            get: { model.showsInMenuBar(id) },
            set: { model.setShowsInMenuBar($0, for: id) }
        )) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .disabled(!model.preferences.menuBarStyle.showsTime)
    }

    private var preview: String {
        guard model.preferences.menuBarStyle != .icon else {
            return String(localized: "Globe icon", comment: "Menu bar preview for icon-only mode")
        }
        return model.menuBarRows.map { row in
            let time = DateFormatting.timeString(
                for: model.displayDate,
                in: row.timeZone,
                format: model.preferences.timeFormat,
                showsSeconds: model.preferences.menuBarShowsSeconds
            )
            return switch model.preferences.menuBarStyle {
            case .icon, .time: time
            case .symbolAndTime: "\(row.symbol) \(time)"
            case .labelAndTime: "\(row.title) \(time)"
            }
        }
        .joined(separator: "   ")
    }
}

// MARK: - Time Travel

private struct TimeTravelSettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $model.preferences.showsTimeTravel) {
                    Text("Show the slider in the popover", comment: "Setting label")
                }

                Picker(selection: $model.preferences.travelStep) {
                    ForEach(TravelStep.allCases) { step in
                        Text(step.label).tag(step)
                    }
                } label: {
                    Text("Slider steps", comment: "Setting label")
                }

                Toggle(isOn: $model.preferences.travelResetsOnClose) {
                    Text("Return to now when the popover closes", comment: "Setting label")
                }
            } header: {
                Text("Behaviour", comment: "Settings section title")
            } footer: {
                Text("The slider spans 24 hours back to 24 hours ahead. It only changes what RXZone displays — your Mac’s clock is never modified.",
                     comment: "Explains that time travel is display-only")
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent {
                    Text(DateFormatting.travelLabel(minutes: Int(model.travelMinutes)))
                        .monospacedDigit()
                } label: {
                    Text("Current offset", comment: "Setting label")
                }

                Button {
                    model.resetTravel()
                } label: {
                    Text("Return to Now", comment: "Button")
                }
                .disabled(!model.isTimeTravelling)
            }
        }
        .formStyle(.grouped)
    }
}
