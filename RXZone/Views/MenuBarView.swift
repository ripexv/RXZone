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

    private let width: CGFloat = PanelMetrics.width

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
                        .padding(.horizontal, PanelMetrics.edge)
                        .padding(.vertical, 10)
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
                // The local clock leads as the header; everything else is a row.
                let local = rows.first(where: \.isLocal)
                let others = rows.filter { !$0.isLocal }

                if let local {
                    LocalClockHeader(
                        row: local,
                        date: model.displayDate,
                        preferences: model.preferences,
                        isInMenuBar: inMenuBar.contains(local.timeZone.identifier),
                        onSetTime: { minutes in
                            model.travel(toMinuteOfDay: minutes, in: local.timeZone, title: local.city)
                        }
                    )
                    .contextMenu { menu(for: local) }
                    if !others.isEmpty { Divider().padding(.horizontal, PanelMetrics.edge) }
                }

                if !others.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(others) { row in
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
                                .padding(.horizontal, PanelMetrics.listInset)
                                .contextMenu { menu(for: row) }
                            }
                        }
                        .padding(.vertical, 6)
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
                    .frame(height: min(listHeight > 0 ? listHeight : estimatedHeight(for: others.count), 360))
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
        }
    }

    /// Shared by the header and the rows. The local clock cannot be removed,
    /// so it simply has no Remove item.
    @ViewBuilder
    private func menu(for row: ZoneRow) -> some View {
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

    /// Stand-in used for the very first frame, before the list has been
    /// measured, so the panel never opens visibly empty.
    private func estimatedHeight(for rowCount: Int) -> CGFloat {
        let row: CGFloat = 58
        return CGFloat(rowCount) * row + 16
    }

    private var preferences: Preferences { model.preferences }

    private var travelBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.2.circlepath")
                .font(.system(size: PanelMetrics.body))
            bannerText
                .font(.system(size: PanelMetrics.body))
                .fontWeight(.medium)
                .lineLimit(1)
            Spacer(minLength: 0)
            // The way back has to be right where the change is announced.
            Button {
                model.resetTravel()
            } label: {
                Text("Now", comment: "Returns from time travel to the present")
                    .font(.system(size: PanelMetrics.body))
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderless)
        }
        .foregroundStyle(Color.accentColor)
        .padding(.horizontal, PanelMetrics.edge)
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
                .font(.system(size: PanelMetrics.title, weight: .semibold))
            Text("Add a city to start tracking it.", comment: "Empty state subtitle")
                .font(.system(size: PanelMetrics.body))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 14) {
            // A raised pill, the same lifted surface as a hovered row, so the
            // one action that adds something reads as a button and not a link.
            Button {
                isAdding = true
            } label: {
                Label {
                    Text("Add Time Zone…", comment: "Popover footer button")
                } icon: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(.background)
                        .shadow(color: .black.opacity(0.10), radius: 3, y: 1)
                )
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Group {
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
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, PanelMetrics.edge)
        .padding(.vertical, 10)
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
