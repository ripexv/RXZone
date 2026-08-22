//
//  AppModel.swift
//  RXZone
//

import Foundation
import Observation
// For `move(fromOffsets:toOffset:)` / `remove(atOffsets:)`, which SwiftUI
// defines on RangeReplaceableCollection and the list editing actions rely on.
import SwiftUI

/// One row as shown in the popover and in Settings.
///
/// The pinned "local" row has no backing `TimeZoneItem`; it always reflects the
/// Mac's current time zone and cannot be edited or removed.
nonisolated struct ZoneRow: Identifiable, Hashable, Sendable {
    let id: UUID
    let timeZone: TimeZone
    let symbol: String
    let title: String
    let subtitle: String
    let isLocal: Bool
    /// True when this row runs on the Mac's own time zone. Set on the pinned
    /// local row and on any saved zone that happens to match it, so the marker
    /// survives when the pinned row is de-duplicated away.
    let isSystemZone: Bool
    /// `false` when the stored identifier is unknown to this macOS version.
    let isAvailable: Bool

    /// Stable identity for the synthetic local row.
    static let localRowID = UUID(uuidString: "00000000-0000-0000-0000-00005A4F4E45")!
}

/// Owns everything the UI reads: persisted preferences, the shared clock, the
/// login-item state, and the transient time travel offset.
@Observable
final class AppModel {

    /// Persisted settings. Any mutation, including one nested inside `zones`,
    /// writes the whole blob back to `UserDefaults`.
    var preferences: Preferences {
        didSet {
            guard preferences != oldValue else { return }
            save()
            syncClockGranularity()
            syncGlobalShortcut()
        }
    }

    /// Time travel offset in minutes. Deliberately not persisted — the app
    /// should always open showing the real current time.
    var travelMinutes: Double = 0 {
        didSet { syncClockGranularity() }
    }

    /// Whether the menu bar popover is currently on screen.
    var isPopoverOpen: Bool = false

    let clock = ClockService()
    let launchAtLogin = LaunchAtLoginService()
    let shortcuts = GlobalShortcutService()

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private static let storageKey = "preferences.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let isFirstLaunch = defaults.data(forKey: Self.storageKey) == nil
        self.preferences = Self.load(from: defaults)
        // Write the seeded list straight away so the starter zones become the
        // user's own list, rather than silently changing under them if a future
        // build ships different defaults.
        if isFirstLaunch { save() }
        syncClockGranularity()
        syncGlobalShortcut()
    }

    /// Binds (or clears) the system-wide shortcut that toggles the popover.
    private func syncGlobalShortcut() {
        shortcuts.update(to: preferences.globalShortcut) {
            MenuBarPresenter.toggle()
        }
    }

    // MARK: - Derived time

    /// The instant every row renders. Equals "now" unless the user is time
    /// travelling; the system clock is never modified.
    var displayDate: Date {
        clock.now.addingTimeInterval(travelMinutes * 60)
    }

    var isTimeTravelling: Bool { travelMinutes != 0 }

    /// Zone that offsets and day differences are measured against.
    var referenceTimeZone: TimeZone { clock.localTimeZone }

    /// Full range of the time travel slider: −24h … +24h.
    static let travelRange: ClosedRange<Double> = -24 * 60 ... 24 * 60

    func resetTravel() { travelMinutes = 0 }

    /// Nudges the offset by whole hours, clamped to the slider's range.
    func nudgeTravel(hours: Int) {
        let proposed = travelMinutes + Double(hours * 60)
        travelMinutes = min(max(proposed, Self.travelRange.lowerBound), Self.travelRange.upperBound)
    }

    // MARK: - Rows

    /// True when the Mac's own zone is already one of the saved zones. A
    /// separate "This Mac" row would then be a second clock showing the same
    /// time, so it is left out.
    var localZoneIsTracked: Bool {
        preferences.zones.contains { $0.identifier == clock.localTimeZone.identifier }
    }

    /// Saved zones, optionally preceded by a row for the Mac's own zone.
    ///
    /// macOS already shows local time in its own menu bar clock, so this row is
    /// redundant most of the time and can be switched off. The exception is time
    /// travel: the system clock does not move with the slider, so without this
    /// row there is nothing to read the shifted offsets against.
    var rows: [ZoneRow] {
        var rows: [ZoneRow] = []
        if (preferences.showsLocalZone || isTimeTravelling), !localZoneIsTracked {
            rows.append(localRow)
        }
        rows.append(contentsOf: preferences.zones.map { row(for: $0) })
        return rows
    }

    var localRow: ZoneRow {
        let zone = clock.localTimeZone
        return ZoneRow(
            id: ZoneRow.localRowID,
            timeZone: zone,
            symbol: TimeZoneCatalog.suggestedSymbol(for: zone.identifier),
            title: String(localized: "This Mac", comment: "Row for the Mac's own time zone"),
            subtitle: TimeZoneCatalog.cityName(for: zone.identifier),
            isLocal: true,
            isSystemZone: true,
            isAvailable: true
        )
    }

    private func row(for item: TimeZoneItem) -> ZoneRow {
        ZoneRow(
            id: item.id,
            timeZone: item.resolvedTimeZone,
            symbol: item.displaySymbol,
            title: item.title,
            subtitle: item.isAvailable
                ? item.subtitle
                : String(localized: "Unavailable on this Mac", comment: "Time zone identifier is unknown"),
            isLocal: false,
            isSystemZone: item.identifier == clock.localTimeZone.identifier,
            isAvailable: item.isAvailable
        )
    }

    /// The clocks shown in the menu bar, in the user's own zone order.
    ///
    /// Falls back to the local zone when nothing is selected, or when every
    /// selected zone has since been deleted, so the status item is never blank.
    var menuBarRows: [ZoneRow] {
        let selected = preferences.zones.filter { preferences.menuBarZoneIDs.contains($0.id) }

        var rows: [ZoneRow] = []
        // Skip the local clock when a selected zone already shows the same
        // time, otherwise the menu bar would repeat itself.
        if preferences.menuBarZoneIDs.contains(ZoneRow.localRowID),
           !selected.contains(where: { $0.identifier == clock.localTimeZone.identifier }) {
            rows.append(localRow)
        }
        rows += selected.map { row(for: $0) }

        // An empty selection means "not configured yet" rather than "blank
        // status item", so the local clock stands in.
        return rows.isEmpty ? [localRow] : rows
    }

    /// All tracked clocks at the displayed instant, ready to paste into a
    /// message. Reads from `displayDate`, so time travelling to a candidate
    /// slot and copying gives the times for that slot rather than for now.
    var meetingTimeText: String {
        DateFormatting.meetingSummary(
            for: rows.map { (title: $0.title, timeZone: $0.timeZone) },
            at: displayDate,
            reference: referenceTimeZone,
            format: preferences.timeFormat
        )
    }

    // MARK: - Menu bar rendering

    /// The exact string the status item draws.
    ///
    /// The Settings preview renders this same value rather than rebuilding it,
    /// so a preview can never promise something the menu bar does not show.
    /// Empty for the icon-only style, which callers draw as an image instead.
    var menuBarText: String {
        guard preferences.menuBarStyle != .icon else { return "" }
        // A leading marker makes an active time travel offset obvious even
        // while the popover is closed.
        let prefix = isTimeTravelling ? "⏱ " : ""
        return prefix + menuBarRows.map(menuBarClock(for:)).joined(separator: "   ")
    }

    /// Time zones the menu bar is currently displaying.
    ///
    /// Keyed by zone rather than by row id on purpose. The pinned local row and
    /// a saved row for the same zone show the same clock, and only one of them
    /// survives de-duplication — but the user is matching *times*, so whichever
    /// row they can see should be the one marked.
    var menuBarZoneIdentifiers: Set<String> {
        Set(menuBarRows.map(\.timeZone.identifier))
    }

    /// The same clocks as one spoken phrase per zone.
    var menuBarAccessibilityText: String {
        menuBarRows
            .map { "\($0.title) \(menuBarTime(for: $0))" }
            .joined(separator: ", ")
    }

    private func menuBarTime(for row: ZoneRow) -> String {
        DateFormatting.timeString(
            for: displayDate,
            in: row.timeZone,
            format: preferences.timeFormat,
            showsSeconds: preferences.menuBarShowsSeconds
        )
    }

    private func menuBarClock(for row: ZoneRow) -> String {
        let time = menuBarTime(for: row)
        return switch preferences.menuBarStyle {
        case .icon: ""
        case .time: time
        case .symbolAndTime: "\(row.symbol) \(time)"
        case .labelAndTime: "\(row.title) \(time)"
        }
    }

    /// Whether a row is currently visible in the menu bar, taking the implicit
    /// local-only default into account.
    func showsInMenuBar(_ id: UUID) -> Bool {
        preferences.menuBarZoneIDs.isEmpty
            ? id == ZoneRow.localRowID
            : preferences.menuBarZoneIDs.contains(id)
    }

    func setShowsInMenuBar(_ shows: Bool, for id: UUID) {
        materializeMenuBarSelection()
        if shows {
            preferences.menuBarZoneIDs.insert(id)
        } else {
            preferences.menuBarZoneIDs.remove(id)
        }
    }

    /// Turns the implicit "empty means local" state into a real selection, so a
    /// later insert cannot silently drop the local clock the user can see.
    private func materializeMenuBarSelection() {
        guard preferences.menuBarZoneIDs.isEmpty else { return }
        preferences.menuBarZoneIDs.insert(ZoneRow.localRowID)
    }

    // MARK: - Editing

    /// Adds a zone and shows it in the menu bar straight away — a zone you just
    /// picked is one you want to see. It can be unticked from the row's context
    /// menu or in Settings.
    /// - Parameter customLabel: the name to show on the row. Set when the zone
    ///   was found under another name, so someone in New Jersey sees "New
    ///   Jersey" rather than "New York" while still tracking `America/New_York`.
    func addZone(identifier: String, customLabel: String = "") {
        guard TimeZone(identifier: identifier) != nil else { return }
        let item = TimeZoneItem(identifier: identifier, customLabel: customLabel)
        preferences.zones.append(item)
        setShowsInMenuBar(true, for: item.id)
    }

    func removeZone(id: UUID) {
        preferences.zones.removeAll { $0.id == id }
        preferences.menuBarZoneIDs.remove(id)
    }

    func removeZones(atOffsets offsets: IndexSet) {
        let removed = Set(offsets.map { preferences.zones[$0].id })
        preferences.zones.remove(atOffsets: offsets)
        preferences.menuBarZoneIDs.subtract(removed)
    }

    func moveZones(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        preferences.zones.move(fromOffsets: offsets, toOffset: destination)
    }

    func updateZone(_ item: TimeZoneItem) {
        guard let index = preferences.zones.firstIndex(where: { $0.id == item.id }) else { return }
        preferences.zones[index] = item
    }

    /// Rows already tracked, keyed by zone plus displayed name, so the picker
    /// only marks as added what the user actually added under that name.
    var trackedKeys: Set<String> {
        Set(preferences.zones.map(\.trackingKey))
    }

    // MARK: - Clock rate

    /// Ticks once a second only while seconds are actually visible somewhere;
    /// otherwise once a minute.
    private func syncClockGranularity() {
        let needsSeconds = (preferences.menuBarStyle.showsTime && preferences.menuBarShowsSeconds)
            || (isPopoverOpen && preferences.showsSecondsInPopover)
        clock.setGranularity(needsSeconds ? .second : .minute)
    }

    func popoverDidAppear() {
        isPopoverOpen = true
        clock.refresh()
        syncClockGranularity()
    }

    func popoverDidDisappear() {
        isPopoverOpen = false
        if preferences.travelResetsOnClose { travelMinutes = 0 }
        syncClockGranularity()
    }

    // MARK: - Persistence

    /// Restores saved preferences, falling back to a working default set if the
    /// stored blob is missing or unreadable.
    private static func load(from defaults: UserDefaults) -> Preferences {
        guard let data = defaults.data(forKey: storageKey) else { return Preferences() }
        do {
            return try JSONDecoder().decode(Preferences.self, from: data)
        } catch {
            // Corrupt payload: drop it so the app stops trying to read it, and
            // start from defaults rather than launching in a broken state.
            defaults.removeObject(forKey: storageKey)
            return Preferences()
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    /// Restores factory settings, including the starter zone list.
    func resetToDefaults() {
        travelMinutes = 0
        preferences = Preferences()
    }
}
