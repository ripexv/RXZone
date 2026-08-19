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

    private let width: CGFloat = 312

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            if isAdding {
                AddTimeZoneView(
                    trackedIdentifiers: model.trackedIdentifiers,
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
                if model.isTimeTravelling, !model.preferences.showsTimeTravel { travelBanner }

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(rows) { row in
                            TimeZoneRow(
                                row: row,
                                date: model.displayDate,
                                reference: model.referenceTimeZone,
                                preferences: model.preferences
                            )
                            .padding(.horizontal, 12)
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
                }
                // Grows with the list but never taller than a comfortable panel.
                .frame(maxHeight: 360)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
    }

    private var travelBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.2.circlepath")
                .imageScale(.small)
            Text("Showing \(DateFormatting.travelLabel(minutes: Int(model.travelMinutes))) from now",
                 comment: "Banner shown while time travelling")
                .font(.caption)
                .fontWeight(.medium)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.accentColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.12))
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
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("\(row.title) — \(date), \(time)", forType: .string)
    }
}
