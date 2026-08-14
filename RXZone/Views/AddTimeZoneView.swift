//
//  AddTimeZoneView.swift
//  RXZone
//

import SwiftUI

/// Searchable picker over the system time zone database.
///
/// Used inline inside the popover and as a sheet in Settings, so it takes plain
/// values and callbacks rather than reaching into `AppModel` directly.
struct AddTimeZoneView: View {
    let trackedIdentifiers: Set<String>
    let referenceDate: Date
    let timeFormat: TimeFormat
    let onSelect: (String) -> Void
    let onClose: () -> Void

    @State private var query = ""
    @FocusState private var isSearchFocused: Bool

    /// Cached rather than recomputed in `body`: the popover re-renders on every
    /// clock tick, and re-scanning 443 zones for an unchanged query is waste.
    @State private var results: [TimeZoneCatalog.Entry] = TimeZoneCatalog.entries

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if results.isEmpty {
                noResults
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(results) { entry in
                            resultRow(entry)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(height: 300)
            }
        }
        .onAppear { isSearchFocused = true }
        .onChange(of: query) { _, newQuery in
            results = TimeZoneCatalog.search(newQuery)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel(Text("Back", comment: "Navigate out of the picker"))

            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .imageScale(.small)
                TextField(
                    text: $query,
                    prompt: Text("Search cities or regions", comment: "Search field placeholder")
                ) {
                    Text("Search time zones", comment: "Search field accessibility label")
                }
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("Clear search", comment: "Button"))
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func resultRow(_ entry: TimeZoneCatalog.Entry) -> some View {
        let isTracked = trackedIdentifiers.contains(entry.identifier)

        return Button {
            onSelect(entry.identifier)
            onClose()
        } label: {
            HStack(spacing: 10) {
                Text(entry.symbol)
                    .font(.title3)
                    .frame(minWidth: 24, alignment: .leading)

                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.city)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text(subtitle(for: entry))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if isTracked {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.secondary)
                        .imageScale(.small)
                } else {
                    Text(time(for: entry))
                        .font(.callout)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(isTracked
            ? Text("Already added", comment: "Tooltip for a zone in the list")
            : Text("Add \(entry.city)", comment: "Tooltip to add a zone"))
        .accessibilityLabel(Text(isTracked
            ? String(localized: "\(entry.city), already added", comment: "Accessibility label")
            : String(localized: "Add \(entry.city), \(time(for: entry))", comment: "Accessibility label")))
    }

    private var noResults: some View {
        VStack(spacing: 4) {
            Text("No matches", comment: "Empty search result title")
                .fontWeight(.medium)
            Text("Try a city, country, or region name.", comment: "Empty search result hint")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
    }

    private func subtitle(for entry: TimeZoneCatalog.Entry) -> String {
        entry.country.isEmpty ? entry.identifier : "\(entry.country) · \(entry.identifier)"
    }

    private func time(for entry: TimeZoneCatalog.Entry) -> String {
        guard let zone = TimeZone(identifier: entry.identifier) else { return "" }
        return DateFormatting.timeString(for: referenceDate, in: zone, format: timeFormat)
    }
}
