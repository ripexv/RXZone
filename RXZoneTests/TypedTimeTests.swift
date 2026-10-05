//
//  TypedTimeTests.swift
//  RXZoneTests
//

import Testing
import Foundation
@testable import RXZone

@Suite("Typed time parsing")
struct TimeInputTests {

    @Test("The ways people write a time are all understood", arguments: [
        ("10", 600), ("10:00", 600), ("10:30", 630), ("10.30", 630), ("1030", 630),
        ("930", 570), ("9:05", 545), ("0", 0), ("00:00", 0), ("23:59", 1439),
        ("22h15", 1335), (" 10:30 ", 630),
    ] as [(String, Int)])
    func twentyFourHour(input: String, expected: Int) {
        #expect(TimeInput.minutes(from: input) == expected)
    }

    @Test("Twelve-hour forms with any spelling of am and pm", arguments: [
        ("10am", 600), ("10 pm", 1320), ("10:30pm", 1350), ("12am", 0), ("12pm", 720),
        ("12:15 a.m.", 15), ("1 p.m.", 780), ("7p", 1140), ("9:45 AM", 585),
    ] as [(String, Int)])
    func twelveHour(input: String, expected: Int) {
        #expect(TimeInput.minutes(from: input) == expected)
    }

    @Test("Nonsense is refused rather than guessed at", arguments: [
        "", "abc", "24:00", "25", "10:60", "10:5", "13pm", "0am", "10:30:00", "1-30", "١٠", "12345",
    ])
    func rejects(input: String) {
        #expect(TimeInput.minutes(from: input) == nil, "\(input) is not a time")
    }
}

@Suite("Jumping to a typed time")
struct TypedTimeTravelTests {

    private func model() -> (AppModel, UserDefaults, String) {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        return (AppModel(defaults: defaults), defaults, name)
    }

    private func reading(_ date: Date, in zone: TimeZone) -> (hour: Int, minute: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour!, parts.minute!)
    }

    @Test("The row the time was typed into reads exactly that time")
    func landsOnTheTypedTime() {
        let (model, defaults, name) = model()
        defer { defaults.removePersistentDomain(forName: name) }

        let london = TimeZone(identifier: "Europe/London")!
        model.travel(toMinuteOfDay: 10 * 60, in: london, title: "London")

        let shown = reading(model.displayDate, in: london)
        #expect(shown.hour == 10 && shown.minute == 0)
    }

    @Test("It is the next occurrence, never one in the past")
    func alwaysAhead() {
        let (model, defaults, name) = model()
        defer { defaults.removePersistentDomain(forName: name) }

        let tokyo = TimeZone(identifier: "Asia/Tokyo")!
        for minute in stride(from: 0, to: 24 * 60, by: 97) {
            model.travel(toMinuteOfDay: minute, in: tokyo, title: "Tokyo")
            #expect(model.displayDate.timeIntervalSince(model.clock.now) > -60,
                    "Scheduling means the upcoming \(minute / 60):\(minute % 60), not the last one")
            #expect(model.displayDate.timeIntervalSince(model.clock.now) <= 24 * 3600)
        }
    }

    @Test("A typed time is pinned, so the clock moving does not drift it")
    func pinnedNotOffset() {
        let (model, defaults, name) = model()
        defer { defaults.removePersistentDomain(forName: name) }

        let london = TimeZone(identifier: "Europe/London")!
        let target = (reading(model.clock.now, in: london).hour + 3) % 24 * 60
        model.travel(toMinuteOfDay: target, in: london, title: "London")
        let before = model.displayDate

        // Simulate the minute ticking over.
        model.clock.refresh()
        #expect(model.displayDate == before, "10:00 must still read 10:00 a minute later")
        #expect(model.pin?.title == "London")
    }

    @Test("Touching the slider releases the pin")
    func sliderReleasesThePin() {
        let (model, defaults, name) = model()
        defer { defaults.removePersistentDomain(forName: name) }

        let london = TimeZone(identifier: "Europe/London")!
        let target = (reading(model.clock.now, in: london).hour + 3) % 24 * 60
        model.travel(toMinuteOfDay: target, in: london, title: "London")
        #expect(model.pin != nil)

        model.travelMinutes = 60
        #expect(model.pin == nil)
    }

    @Test("Returning to now clears both the offset and the pin")
    func resetClearsEverything() {
        let (model, defaults, name) = model()
        defer { defaults.removePersistentDomain(forName: name) }

        let london = TimeZone(identifier: "Europe/London")!
        let target = (reading(model.clock.now, in: london).hour + 3) % 24 * 60
        model.travel(toMinuteOfDay: target, in: london, title: "London")
        model.resetTravel()

        #expect(model.pin == nil)
        #expect(!model.isTimeTravelling)
    }

    @Test("Typing the time already on screen is not time travel")
    func currentTimeIsANoOp() {
        let (model, defaults, name) = model()
        defer { defaults.removePersistentDomain(forName: name) }

        let london = TimeZone(identifier: "Europe/London")!
        let now = reading(model.clock.now, in: london)
        model.travel(toMinuteOfDay: now.hour * 60 + now.minute, in: london, title: "London")
        #expect(model.pin == nil)
        #expect(!model.isTimeTravelling)
    }

    @Test("Nudging a typed time moves on from it")
    func nudgeStartsFromThePin() {
        let (model, defaults, name) = model()
        defer { defaults.removePersistentDomain(forName: name) }

        let london = TimeZone(identifier: "Europe/London")!
        let target = (reading(model.clock.now, in: london).hour + 3) % 24 * 60
        model.travel(toMinuteOfDay: target, in: london, title: "London")
        let offset = model.travelOffsetMinutes

        model.nudgeTravel(hours: 1)
        #expect(model.travelOffsetMinutes == offset + 60)
    }

    @Test("A time that does not exist on a DST morning lands on the next one that does")
    func springForwardGap() {
        var calendar = Calendar(identifier: .gregorian)
        let newYork = TimeZone(identifier: "America/New_York")!
        calendar.timeZone = newYork
        // 02:30 never happens on 8 March 2026 in New York: clocks jump 02:00 → 03:00.
        let after = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 0))!
        let landed = calendar.nextDate(
            after: after,
            matching: DateComponents(hour: 2, minute: 30, second: 0),
            matchingPolicy: .nextTime)!
        let parts = calendar.dateComponents([.day, .hour], from: landed)
        #expect(parts.day == 8 && parts.hour == 3, "The policy the model relies on must not skip a whole day")
    }
}
