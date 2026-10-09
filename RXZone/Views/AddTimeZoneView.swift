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
    /// Keys of rows the user already has, from `TimeZoneItem.trackingKey`.
    let trackedKeys: Set<String>
    let referenceDate: Date
    let timeFormat: TimeFormat
    /// Receives the zone identifier plus, when the match came from an alias,
    /// the name the user actually searched for — so a row for Las Vegas can be
    /// labelled "Las Vegas" while still tracking `America/Los_Angeles`.
    let onSelect: (String, String?) -> Void
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
                    .padding(.horizontal, PanelMetrics.listInset)
                    .padding(.vertical, 6)
                }
                .frame(height: Self.listHeight)
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
            .font(.system(size: 14))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 8, style: .continuous))
        }
        .padding(.horizontal, PanelMetrics.edge)
        .padding(.vertical, 10)
    }

    private func resultRow(_ entry: TimeZoneCatalog.Entry) -> some View {
        // When the query matched an alias, lead with the place the user asked
        // for and say plainly whose zone it shares. Nothing here invents a time
        // zone — the identifier stays exactly what Foundation gave us.
        let alias = TimeZoneCatalog.matchedAlias(for: entry, query: query)
        let title = alias ?? entry.city
        // Keyed by name as well as zone: having New York does not mean the user
        // already has Washington DC, even though the two share a zone.
        let isTracked = trackedKeys.contains(
            TimeZoneItem.trackingKey(identifier: entry.identifier, title: title))

        return Button {
            onSelect(entry.identifier, alias)
            onClose()
        } label: {
            SearchResultRow(
                symbol: entry.symbol,
                title: title,
                subtitle: alias == nil
                    ? subtitle(for: entry)
                    : String(localized: "Same zone as \(entry.city)",
                             comment: "Shown when a searched city shares another city's time zone"),
                time: time(for: entry),
                isTracked: isTracked,
                sky: SolarPosition.sky(at: referenceDate, in: entry.identifier)
            )
        }
        .buttonStyle(.plain)
        // The tooltip always names the real identifier, so the underlying zone
        // is one hover away no matter which name the row is showing.
        .help(isTracked
            ? Text("Already added · \(entry.identifier)", comment: "Tooltip for a zone in the list")
            : Text("Add \(title) · \(entry.identifier)", comment: "Tooltip to add a zone"))
        .accessibilityLabel(Text(isTracked
            ? String(localized: "\(title), already added", comment: "Accessibility label")
            : String(localized: "Add \(title), \(time(for: entry))", comment: "Accessibility label")))
    }

    private var noResults: some View {
        VStack(spacing: 4) {
            Text("No matches", comment: "Empty search result title")
                .font(.system(size: PanelMetrics.title, weight: .semibold))
            Text("Try a city, country, or region name.", comment: "Empty search result hint")
                .font(.system(size: PanelMetrics.body))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.listHeight)
    }

    /// Tall enough that the picker does not feel like a smaller window than
    /// the clock list it was opened from.
    private static let listHeight: CGFloat = 400

    private func subtitle(for entry: TimeZoneCatalog.Entry) -> String {
        entry.country.isEmpty ? entry.identifier : "\(entry.country) · \(entry.identifier)"
    }

    private func time(for entry: TimeZoneCatalog.Entry) -> String {
        guard let zone = TimeZone(identifier: entry.identifier) else { return "" }
        return DateFormatting.timeString(for: referenceDate, in: zone, format: timeFormat)
    }
}

/// One search result, drawn at the same scale as a clock row — same disc,
/// same type sizes, same lifted card on hover — so the picker reads as part of
/// the panel rather than a smaller window inside it.
private struct SearchResultRow: View {
    let symbol: String
    let title: String
    let subtitle: String
    let time: String
    let isTracked: Bool
    let sky: SkyScene?

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            EmojiDisc(symbol: symbol, size: PanelMetrics.avatar, sky: sky)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: PanelMetrics.title, weight: .semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: PanelMetrics.body))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if isTracked {
                Image(systemName: "checkmark")
                    .font(.system(size: PanelMetrics.body, weight: .semibold))
                    .foregroundStyle(.secondary)
            } else {
                Text(time)
                    .font(.system(size: PanelMetrics.title, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, PanelMetrics.edge - PanelMetrics.listInset)
        .background {
            if isHovering {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 1)
            }
        }
        .contentShape(.rect)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}
