//
//  MenuBarView.swift
//  RXZone
//

import SwiftUI
import AppKit

/// Contents of the menu bar popover.
struct MenuBarView: View {
    @Environment(AppModel.self) private var model
    @State private var isAdding = false
    /// Measured height of the clock list.
    ///
    /// A `ScrollView` has no height of its own — it accepts whatever it is
    /// offered — while the `MenuBarExtra` panel sizes itself to its content.
    /// Each waits for the other and the list resolves to zero, leaving a panel
    /// with nothing in it but the footer. Measuring the content breaks the tie.
    @State private var listHeight: CGFloat = 0

    private let width: CGFloat = 312

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            if isAdding {
                AddTimeZoneView(
                    trackedKeys: model.trackedKeys,
                    referenceDate: model.displayDate,
                    timeFormat: model.preferences.timeFormat,
                    onSelect: { model.addZone(identifier: $0, customLabel: $1 ?? "") },
                    onClose: { isAdding = false }
                )
            } else {
                clockList
                if model.preferences.showsTimeTravel {
                    Divider()
                    TimeTravelControl(model: model)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    .background {
                        GeometryReader { proxy in
                            Color.clear
                                .onAppear { listHeight = proxy.size.height }
                                .onChange(of: proxy.size.height) { _, new in listHeight = new }
                        }
                    }
                }
                Divider()
                footer
            }
        }
        .frame(width: width)
        .onAppear { model.popoverDidAppear() }
        .onDisappear {
            isAdding = false
            model.popoverDidDisappear()
        }
    }

    // MARK: - Clocks

    @ViewBuilder
    private var clockList: some View {
        let rows = model.rows

        if rows.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                // Only needed when the slider is collapsed; otherwise the
                // control itself already states the offset.
                // A typed time always gets the banner, because it names the row and
                // the time; the slider alone already shows a bare offset.
                if model.pin != nil || (model.isTimeTravelling && !model.preferences.showsTimeTravel) {
                    travelBanner
                }

                let inMenuBar = model.menuBarZoneIdentifiers

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(rows) { row in
                            TimeZoneRow(
                                row: row,
                                date: model.displayDate,
                                reference: model.referenceTimeZone,
                                preferences: model.preferences,
                                isInMenuBar: inMenuBar.contains(row.timeZone.identifier),
                                onSetTime: { minutes in
                                    model.travel(toMinuteOfDay: minutes, in: row.timeZone, title: row.title)
                                }
                            )
                            .padding(.horizontal, 8)
                            .contextMenu {
                                Toggle(isOn: Binding(
                                    get: { model.showsInMenuBar(row.id) },
                                    set: { model.setShowsInMenuBar($0, for: row.id) }
                                )) {
                                    Text("Show in Menu Bar", comment: "Context menu toggle")
                                }

                                Button {
                                    copyTime(for: row)
                                } label: {
                                    Text("Copy Time", comment: "Context menu action")
                                }

                                Button {
                                    copy(model.meetingTimeText)
                                } label: {
                                    Text("Copy All Times", comment: "Context menu action")
                                }

                                if !row.isLocal {
                                    Divider()
                                    Button(role: .destructive) {
                                        model.removeZone(id: row.id)
                                    } label: {
                                        Text("Remove \(row.title)", comment: "Context menu action")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .background {
                        GeometryReader { proxy in
                            Color.clear
                                .onAppear { listHeight = proxy.size.height }
                                .onChange(of: proxy.size.height) { _, new in listHeight = new }
                        }
                    }
                }
                // Grows with the list but never taller than a comfortable panel.
                // The estimate covers only the first frame; once the content has
                // been measured that number is used exactly, so an estimate that
                // overshoots does not leave a permanent gap.
                .frame(height: min(listHeight > 0 ? listHeight : estimatedHeight(for: rows.count), 360))
                .scrollBounceBehavior(.basedOnSize)
            }
        }
    }

    /// Stand-in used for the very first frame, before the list has been
    /// measured, so the panel never opens visibly empty.
    private func estimatedHeight(for rowCount: Int) -> CGFloat {
        let row: CGFloat = preferences.showsDate || preferences.showsOffsetFromLocal ? 44 : 32
        return CGFloat(rowCount) * row + 16
    }

    private var preferences: Preferences { model.preferences }

    private var travelBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.2.circlepath")
                .imageScale(.small)
            bannerText
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
            Spacer(minLength: 0)
            // The way back has to be right where the change is announced.
            Button {
                model.resetTravel()
            } label: {
                Text("Now", comment: "Returns from time travel to the present")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderless)
        }
        .foregroundStyle(Color.accentColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.12))
    }

    /// Names the typed time and the row it was typed into when there is one —
    /// "10:00 in London" says far more than "+3h from now".
    private var bannerText: Text {
        let offset = DateFormatting.travelLabel(minutes: model.travelOffsetMinutes)
        guard let pin = model.pin else {
            return Text("Showing \(offset) from now", comment: "Banner shown while time travelling")
        }
        let time = DateFormatting.timeString(
            for: pin.date, in: pin.timeZone, format: model.preferences.timeFormat)
        return Text("\(time) in \(pin.title) · \(offset)",
                    comment: "Banner after typing a time into a row: time, row name, offset from now")
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "globe")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("No time zones yet", comment: "Empty state title")
                .font(.callout)
                .fontWeight(.medium)
            Text("Add a city to start tracking it.", comment: "Empty state subtitle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                isAdding = true
            } label: {
                Label {
                    Text("Add Time Zone…", comment: "Popover footer button")
                } icon: {
                    Image(systemName: "plus")
                }
                .font(.callout)
            }

            Spacer(minLength: 0)

            Button {
                model.preferences.showsTimeTravel.toggle()
                // Leaving a hidden offset applied would silently show wrong times.
                if !model.preferences.showsTimeTravel { model.resetTravel() }
            } label: {
                Image(systemName: model.preferences.showsTimeTravel
                      ? "clock.arrow.2.circlepath"
                      : "clock")
            }
            .foregroundStyle(model.preferences.showsTimeTravel ? Color.accentColor : Color.secondary)
            .help(Text("Time travel", comment: "Tooltip"))
            .accessibilityLabel(Text("Time travel", comment: "Button"))

            SettingsLink {
                Image(systemName: "gearshape")
            }
            .help(Text("Settings", comment: "Tooltip"))
            .accessibilityLabel(Text("Settings", comment: "Button"))

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .help(Text("Quit RXZone", comment: "Tooltip"))
            .accessibilityLabel(Text("Quit RXZone", comment: "Button"))
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    /// Puts the row's rendered time on the pasteboard — handy when scheduling.
    private func copyTime(for row: ZoneRow) {
        let time = DateFormatting.timeString(
            for: model.displayDate,
            in: row.timeZone,
            format: model.preferences.timeFormat
        )
        let date = DateFormatting.dateString(for: model.displayDate, in: row.timeZone)
        copy("\(row.title) — \(date), \(time)")
    }

    private func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
