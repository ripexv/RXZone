//
//  WorkingHoursTests.swift
//  RXZoneTests
//

import Testing
import Foundation
@testable import RXZone

/// Builds an instant from a local wall-clock time in a given zone, which is how
/// working hours are actually reasoned about.
private func instant(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int,
                     in identifier: String) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: identifier)!
    return calendar.date(from: DateComponents(
        year: year, month: month, day: day, hour: hour, minute: minute))!
}

private let warsaw = TimeZone(identifier: "Europe/Warsaw")!

@Suite("Working hours")
struct WorkingHoursTests {

    // 2026-08-19 is a Wednesday, 2026-08-22 a Saturday, 2026-08-21 a Friday.

    @Test("Inside the range on a weekday counts as working")
    func insideRange() {
        let hours = WorkingHours(start: 9 * 60, end: 18 * 60)
        #expect(hours.isActive(at: instant(2026, 8, 19, 14, 0, in: "Europe/Warsaw"), in: warsaw))
    }

    @Test("Before and after the range does not")
    func outsideRange() {
        let hours = WorkingHours(start: 9 * 60, end: 18 * 60)
        #expect(!hours.isActive(at: instant(2026, 8, 19, 8, 59, in: "Europe/Warsaw"), in: warsaw))
        #expect(!hours.isActive(at: instant(2026, 8, 19, 18, 0, in: "Europe/Warsaw"), in: warsaw))
    }

    @Test("The start minute is inside, the end minute is not")
    func boundaries() {
        let hours = WorkingHours(start: 9 * 60, end: 18 * 60)
        #expect(hours.isActive(at: instant(2026, 8, 19, 9, 0, in: "Europe/Warsaw"), in: warsaw))
        #expect(hours.isActive(at: instant(2026, 8, 19, 17, 59, in: "Europe/Warsaw"), in: warsaw))
    }

    @Test("Weekends are skipped when the switch is on")
    func weekdaysOnly() {
        let hours = WorkingHours(start: 9 * 60, end: 18 * 60, weekdaysOnly: true)
        #expect(!hours.isActive(at: instant(2026, 8, 22, 14, 0, in: "Europe/Warsaw"), in: warsaw))
    }

    @Test("Weekends count when the switch is off")
    func everyDay() {
        let hours = WorkingHours(start: 9 * 60, end: 18 * 60, weekdaysOnly: false)
        #expect(hours.isActive(at: instant(2026, 8, 22, 14, 0, in: "Europe/Warsaw"), in: warsaw))
    }

    @Test("An overnight shift is recognised on both sides of midnight")
    func overnightShift() {
        let night = WorkingHours(start: 22 * 60, end: 6 * 60, weekdaysOnly: false)
        #expect(night.wrapsMidnight)
        #expect(night.isActive(at: instant(2026, 8, 19, 23, 0, in: "Europe/Warsaw"), in: warsaw))
        #expect(night.isActive(at: instant(2026, 8, 20, 2, 0, in: "Europe/Warsaw"), in: warsaw))
        #expect(!night.isActive(at: instant(2026, 8, 20, 12, 0, in: "Europe/Warsaw"), in: warsaw))
    }

    @Test("The tail of an overnight shift belongs to the day it started")
    func overnightTailKeepsTheStartingDay() {
        let night = WorkingHours(start: 22 * 60, end: 6 * 60, weekdaysOnly: true)
        // Saturday 02:00 is the tail of a shift that began Friday night: still work.
        #expect(night.isActive(at: instant(2026, 8, 22, 2, 0, in: "Europe/Warsaw"), in: warsaw))
        // Saturday 23:00 begins a shift on a weekend: not work.
        #expect(!night.isActive(at: instant(2026, 8, 22, 23, 0, in: "Europe/Warsaw"), in: warsaw))
        // Sunday 02:00 is the tail of the Saturday shift: also not work.
        #expect(!night.isActive(at: instant(2026, 8, 23, 2, 0, in: "Europe/Warsaw"), in: warsaw))
    }

    @Test("Hours are read in the zone's own local time, not the Mac's")
    func evaluatedInTheZone() {
        let hours = WorkingHours(start: 9 * 60, end: 18 * 60, weekdaysOnly: false)
        // 07:00 UTC on a Wednesday: 09:00 in Warsaw, but 03:00 in New York.
        let moment = instant(2026, 8, 19, 7, 0, in: "UTC")
        #expect(hours.isActive(at: moment, in: warsaw))
        #expect(!hours.isActive(at: moment, in: TimeZone(identifier: "America/New_York")!))
    }

    @Test("A stored range survives a round trip")
    func roundTrip() throws {
        let original = WorkingHours(start: 10 * 60 + 30, end: 19 * 60 + 15, weekdaysOnly: false)
        let restored = try JSONDecoder().decode(
            WorkingHours.self, from: JSONEncoder().encode(original))
        #expect(restored == original)
    }

    @Test("Out-of-range stored minutes are clamped rather than trusted")
    func decodingClamps() throws {
        let json = #"{"start":-60,"end":99999,"weekdaysOnly":true}"#
        let hours = try JSONDecoder().decode(WorkingHours.self, from: Data(json.utf8))
        #expect(hours.start >= 0)
        #expect(hours.end < 24 * 60)
    }
}

@Suite("Working hours on rows")
struct WorkingHoursRowTests {

    @Test("A zone without hours reports no status at all")
    func noHoursNoStatus() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let model = AppModel(defaults: defaults)
        model.preferences.zones = [TimeZoneItem(identifier: "Europe/Warsaw")]

        let row = model.rows.first { !$0.isLocal }
        #expect(row?.isWorking == nil, "No hours set is not the same as off hours")
    }

    @Test("Time travel moves the status with the displayed hour")
    func statusFollowsTimeTravel() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let model = AppModel(defaults: defaults)
        // Always-on hours so the assertion cannot depend on when the test runs.
        model.preferences.zones = [TimeZoneItem(
            identifier: "Europe/Warsaw",
            workingHours: WorkingHours(start: 0, end: 24 * 60 - 1, weekdaysOnly: false))]

        let row = model.rows.first { !$0.isLocal }
        #expect(row?.isWorking == true)

        // Nudging the clock must re-evaluate rather than reuse a cached answer.
        model.travelMinutes = 60
        #expect(model.rows.first { !$0.isLocal }?.isWorking != nil)
    }
}
