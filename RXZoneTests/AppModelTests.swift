//
//  AppModelTests.swift
//  RXZoneTests
//

import Testing
import Foundation
@testable import RXZone

/// Each test gets its own defaults suite so nothing touches the real app's
/// stored configuration, and tests cannot interfere with one another.
private func makeModel(
    suite name: String = UUID().uuidString,
    seed: (UserDefaults) -> Void = { _ in }
) -> (model: AppModel, defaults: UserDefaults, name: String) {
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    seed(defaults)
    return (AppModel(defaults: defaults), defaults, name)
}

private func titles(_ rows: [ZoneRow]) -> [String] { rows.map(\.title) }

@Suite("Menu bar selection")
struct MenuBarSelectionTests {

    @Test("A fresh install shows the Mac's own zone")
    func defaultsToLocal() {
        let (model, defaults, name) = makeModel()
        defer { defaults.removePersistentDomain(forName: name) }

        #expect(model.menuBarRows.count == 1)
        #expect(model.menuBarRows[0].isLocal)
        #expect(model.showsInMenuBar(ZoneRow.localRowID))
    }

    @Test("A newly added zone appears in the menu bar without extra setup")
    func addingAZoneShowsIt() {
        let (model, defaults, name) = makeModel()
        defer { defaults.removePersistentDomain(forName: name) }

        model.addZone(identifier: "Europe/Berlin")
        let berlin = model.preferences.zones.last!

        #expect(model.showsInMenuBar(berlin.id))
        #expect(titles(model.menuBarRows).contains("Berlin"))
    }

    @Test("Adding the first zone does not evict the local clock")
    func localSurvivesTheFirstAdd() {
        let (model, defaults, name) = makeModel()
        defer { defaults.removePersistentDomain(forName: name) }

        model.addZone(identifier: "Europe/Berlin")
        #expect(model.menuBarRows.contains { $0.isLocal },
                "The implicit local selection must be made explicit before inserting")
        #expect(model.menuBarRows.count == 2)
    }

    @Test("The local clock can be turned off once other zones are shown")
    func localCanBeRemoved() {
        let (model, defaults, name) = makeModel()
        defer { defaults.removePersistentDomain(forName: name) }

        model.addZone(identifier: "Europe/Berlin")
        model.setShowsInMenuBar(false, for: ZoneRow.localRowID)

        #expect(!model.menuBarRows.contains { $0.isLocal })
        #expect(titles(model.menuBarRows) == ["Berlin"])
    }

    @Test("Deleting a zone drops it from the menu bar selection too")
    func removingClearsTheSelection() {
        let (model, defaults, name) = makeModel()
        defer { defaults.removePersistentDomain(forName: name) }

        model.addZone(identifier: "Europe/Berlin")
        let berlin = model.preferences.zones.last!
        model.removeZone(id: berlin.id)

        #expect(!model.preferences.menuBarZoneIDs.contains(berlin.id),
                "A deleted zone must not leave an orphaned id behind")
        #expect(!titles(model.menuBarRows).contains("Berlin"))
    }

    @Test("Deleting by offset also clears the selection")
    func removingByOffsetClearsTheSelection() {
        let (model, defaults, name) = makeModel()
        defer { defaults.removePersistentDomain(forName: name) }

        model.addZone(identifier: "Europe/Berlin")
        model.addZone(identifier: "Asia/Dubai")
        let ids = Set(model.preferences.zones.map(\.id))
        model.removeZones(atOffsets: IndexSet(0..<model.preferences.zones.count))

        #expect(model.preferences.zones.isEmpty)
        #expect(model.preferences.menuBarZoneIDs.intersection(ids).isEmpty)
    }

    @Test("The status item never goes blank")
    func neverEmpty() {
        let (model, defaults, name) = makeModel()
        defer { defaults.removePersistentDomain(forName: name) }

        model.setShowsInMenuBar(false, for: ZoneRow.localRowID)
        for zone in model.preferences.zones { model.setShowsInMenuBar(false, for: zone.id) }

        #expect(model.menuBarRows.count == 1)
        #expect(model.menuBarRows[0].isLocal, "An empty selection falls back to the local clock")
    }

    @Test("Menu bar order follows the user's zone order, not insertion order")
    func orderFollowsTheList() {
        let (model, defaults, name) = makeModel()
        defer { defaults.removePersistentDomain(forName: name) }

        model.preferences.zones = []
        model.addZone(identifier: "Asia/Tokyo")
        model.addZone(identifier: "Europe/Berlin")
        model.moveZones(fromOffsets: IndexSet(integer: 1), toOffset: 0)

        #expect(titles(model.menuBarRows).suffix(2) == ["Berlin", "Tokyo"])
    }
}

@Suite("Time travel")
struct TimeTravelTests {

    @Test("The offset is clamped to the slider's range")
    func nudgeClamps() {
        let (model, defaults, name) = makeModel()
        defer { defaults.removePersistentDomain(forName: name) }

        for _ in 0..<40 { model.nudgeTravel(hours: 1) }
        #expect(model.travelMinutes == AppModel.travelRange.upperBound)

        for _ in 0..<80 { model.nudgeTravel(hours: -1) }
        #expect(model.travelMinutes == AppModel.travelRange.lowerBound)
    }

    @Test("The displayed date moves by exactly the offset")
    func displayDateShifts() {
        let (model, defaults, name) = makeModel()
        defer { defaults.removePersistentDomain(forName: name) }

        let base = model.displayDate
        model.travelMinutes = 180
        #expect(model.displayDate.timeIntervalSince(base) == 180 * 60)
        #expect(model.isTimeTravelling)

        model.resetTravel()
        #expect(!model.isTimeTravelling)
    }

    @Test("Travel is transient and never persisted")
    func travelIsNotPersisted() {
        let name = UUID().uuidString
        let (model, defaults, _) = makeModel(suite: name)
        defer { defaults.removePersistentDomain(forName: name) }

        model.travelMinutes = 300
        let relaunched = AppModel(defaults: defaults)
        #expect(relaunched.travelMinutes == 0, "A relaunch must show the real current time")
    }

    @Test("Closing the popover returns to now when configured to")
    func resetOnClose() {
        let (model, defaults, name) = makeModel()
        defer { defaults.removePersistentDomain(forName: name) }

        model.preferences.travelResetsOnClose = true
        model.travelMinutes = 120
        model.popoverDidDisappear()
        #expect(model.travelMinutes == 0)
    }

    @Test("The offset survives closing when the user asked it to")
    func keepOnClose() {
        let (model, defaults, name) = makeModel()
        defer { defaults.removePersistentDomain(forName: name) }

        model.preferences.travelResetsOnClose = false
        model.travelMinutes = 120
        model.popoverDidDisappear()
        #expect(model.travelMinutes == 120)
    }
}

@Suite("Persistence")
struct AppModelPersistenceTests {

    @Test("Settings survive a relaunch")
    func settingsRoundTrip() {
        let name = UUID().uuidString
        let (model, defaults, _) = makeModel(suite: name)
        defer { defaults.removePersistentDomain(forName: name) }

        model.preferences.timeFormat = .twentyFourHour
        model.preferences.showsTimeTravel = true
        model.addZone(identifier: "America/Denver")

        let relaunched = AppModel(defaults: defaults)
        #expect(relaunched.preferences.timeFormat == .twentyFourHour)
        #expect(relaunched.preferences.showsTimeTravel)
        #expect(relaunched.preferences.zones.contains { $0.identifier == "America/Denver" })
        #expect(titles(relaunched.menuBarRows).contains("Denver"))
    }

    @Test("A corrupt stored blob resets to a working configuration")
    func corruptBlobRecovers() {
        let name = UUID().uuidString
        let (model, defaults, _) = makeModel(suite: name) { defaults in
            defaults.set(Data("garbage, not JSON".utf8), forKey: "preferences.v1")
        }
        defer { defaults.removePersistentDomain(forName: name) }

        #expect(!model.preferences.zones.isEmpty, "Should fall back to defaults, not launch empty")
        #expect(model.preferences.timeFormat == .system)
        #expect(defaults.data(forKey: "preferences.v1") == nil,
                "The unreadable blob should be discarded so it is not re-read forever")
    }

    @Test("Resetting restores the starter configuration")
    func resetToDefaults() {
        let (model, defaults, name) = makeModel()
        defer { defaults.removePersistentDomain(forName: name) }

        model.preferences.zones = []
        model.travelMinutes = 60
        model.resetToDefaults()

        #expect(model.travelMinutes == 0)
        #expect(!model.preferences.zones.isEmpty)
    }

    @Test("An unknown identifier is refused rather than stored")
    func rejectsUnknownZone() {
        let (model, defaults, name) = makeModel()
        defer { defaults.removePersistentDomain(forName: name) }

        let before = model.preferences.zones.count
        model.addZone(identifier: "Mars/Olympus_Mons")
        #expect(model.preferences.zones.count == before)
    }
}
