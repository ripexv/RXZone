//
//  SettingsView.swift
//  RXZone
//

import SwiftUI

/// Native Settings window, opened from the popover's gear button or ⌘,
struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        // `.tabItem` rather than the `Tab` type, which is macOS 15 and up. The
        // rendered result is identical and this builds against macOS 14.
        TabView {
            GeneralSettingsView(model: model)
                .tabItem {
                    Label {
                        Text("General", comment: "Settings tab")
                    } icon: {
                        Image(systemName: "gearshape")
                    }
                }

            TimeZoneSettingsView(model: model)
                .tabItem {
                    Label {
                        Text("Time Zones", comment: "Settings tab")
                    } icon: {
                        Image(systemName: "globe")
                    }
                }

            MenuBarSettingsView(model: model)
                .tabItem {
                    Label {
                        Text("Menu Bar", comment: "Settings tab")
                    } icon: {
                        Image(systemName: "menubar.rectangle")
                    }
                }

            TimeTravelSettingsView(model: model)
                .tabItem {
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
            EmojiField(
                symbol: binding.symbol,
                fallback: TimeZoneCatalog.suggestedSymbol(for: item.identifier)
            )

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

            WorkingHoursField(hours: binding.workingHours, format: model.preferences.timeFormat)

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

/// Emoji picker for a row's symbol.
///
/// Replaces a plain text field, which accepted anything typed into it — a city
/// name left two stray letters standing in for a flag. Picking is now the
/// primary path; the field below the grid stays for pasting or for the system
/// palette, and silently drops whatever is not an emoji.
private struct EmojiField: View {
    @Binding var symbol: String
    /// Shown greyed when the user has cleared the field.
    let fallback: String

    @State private var isPicking = false
    @State private var pasted = ""
    @FocusState private var isFieldFocused: Bool

    private let columns = Array(repeating: GridItem(.fixed(30), spacing: 2), count: 8)

    var body: some View {
        Button {
            isPicking = true
        } label: {
            Text(symbol.isEmpty ? fallback : symbol)
                .font(.title3)
                .opacity(symbol.isEmpty ? 0.4 : 1)
                .frame(width: 40, height: 22)
                .contentShape(.rect)
        }
        .buttonStyle(.borderless)
        .help(Text("Choose an emoji", comment: "Tooltip"))
        .accessibilityLabel(Text("Choose an emoji", comment: "Button"))
        .popover(isPresented: $isPicking, arrowEdge: .bottom) { picker }
    }

    private var picker: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(EmojiSuggestions.all, id: \.self) { option in
                    Button {
                        symbol = option
                        isPicking = false
                    } label: {
                        Text(option)
                            .font(.title3)
                            .frame(width: 30, height: 28)
                            .background(
                                symbol == option ? Color.accentColor.opacity(0.2) : .clear,
                                in: .rect(cornerRadius: 5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            HStack(spacing: 8) {
                TextField(text: $pasted, prompt: Text("Paste any emoji", comment: "Field prompt")) {
                    Text("Custom emoji", comment: "Accessibility label")
                }
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .focused($isFieldFocused)
                .onChange(of: pasted) { _, new in
                    // Filtered on the way in, so nothing invalid is ever stored.
                    let cleaned = TimeZoneItem.sanitizedSymbol(new)
                    if !cleaned.isEmpty {
                        symbol = cleaned
                        pasted = ""
                        isPicking = false
                    } else if !new.isEmpty {
                        pasted = ""
                    }
                }

                Button {
                    symbol = ""
                    isPicking = false
                } label: {
                    Text("Reset", comment: "Clears a custom emoji back to the region flag")
                }
            }

            Text("Press Control-Command-Space for the system emoji picker.",
                 comment: "Hint about the macOS emoji palette")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: 274)
        .onAppear { isFieldFocused = true }
    }
}

/// Compact working-hours control: a summary in the list row, the editor behind
/// a popover so the row itself stays readable.
private struct WorkingHoursField: View {
    @Binding var hours: WorkingHours?
    let format: TimeFormat

    @State private var isEditing = false

    var body: some View {
        Button {
            isEditing = true
        } label: {
            Text(summary)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(hours == nil ? .secondary : .primary)
        }
        .buttonStyle(.borderless)
        .help(Text("Working hours for this zone", comment: "Tooltip"))
        .popover(isPresented: $isEditing, arrowEdge: .bottom) { editor }
    }

    private var summary: String {
        guard let hours else {
            return String(localized: "Set hours…", comment: "Placeholder when no working hours are set")
        }
        return "\(label(hours.start))–\(label(hours.end))"
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: isEnabled) {
                Text("Working hours", comment: "Toggle in the working hours editor")
            }

            if hours != nil {
                DatePicker(selection: time(\.start), displayedComponents: .hourAndMinute) {
                    Text("From", comment: "Start of working hours")
                }
                DatePicker(selection: time(\.end), displayedComponents: .hourAndMinute) {
                    Text("To", comment: "End of working hours")
                }
                Toggle(isOn: weekdaysOnly) {
                    Text("Weekdays only", comment: "Skip Saturday and Sunday")
                }

                Text(hours?.wrapsMidnight == true
                     ? String(localized: "Runs past midnight into the next day.",
                              comment: "Explains an overnight shift")
                     : String(localized: "In this zone's own local time.",
                              comment: "Clarifies which clock the hours refer to"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(width: 250)
    }

    // MARK: - Bindings

    private var isEnabled: Binding<Bool> {
        Binding(get: { hours != nil }, set: { hours = $0 ? WorkingHours() : nil })
    }

    private var weekdaysOnly: Binding<Bool> {
        Binding(get: { hours?.weekdaysOnly ?? true }, set: { hours?.weekdaysOnly = $0 })
    }

    /// `DatePicker` speaks `Date`, the model stores minutes from midnight. The
    /// anchor day is arbitrary and never leaves this binding.
    private func time(_ keyPath: WritableKeyPath<WorkingHours, Int>) -> Binding<Date> {
        Binding(
            get: { date(fromMinutes: hours?[keyPath: keyPath] ?? 0) },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                hours?[keyPath: keyPath] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }

    private func date(fromMinutes minutes: Int) -> Date {
        var parts = DateComponents()
        parts.year = 2000
        parts.month = 1
        parts.day = 1
        parts.hour = minutes / 60
        parts.minute = minutes % 60
        return Calendar.current.date(from: parts) ?? Date()
    }

    private func label(_ minutes: Int) -> String {
        DateFormatting.timeString(for: date(fromMinutes: minutes), in: .current, format: format)
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

    /// Rendered by the model, not rebuilt here — a preview that assembled its
    /// own string could quietly disagree with the real menu bar.
    private var preview: String {
        model.preferences.menuBarStyle == .icon
            ? String(localized: "Globe icon", comment: "Menu bar preview for icon-only mode")
            : model.menuBarText
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
