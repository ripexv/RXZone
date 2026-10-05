//
//  ClockChangeTests.swift
//  RXZoneTests
//
//  Transition instants below were read from Foundation for 2026, not written
//  from memory: London 25 Oct 01:00 UTC, New York 1 Nov 06:00 UTC, Sydney
//  3 Oct 16:00 UTC, Lord Howe 3 Oct 15:30 UTC (a 30-minute shift).
//

import Testing
import Foundation
@testable import RXZone

private func utc(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar.date(from: DateComponents(
        year: 2026, month: month, day: day, hour: hour, minute: minute))!
}

private func zone(_ identifier: String) -> TimeZone { TimeZone(identifier: identifier)! }

private func notice(_ identifier: String, reference: String = "Europe/Istanbul", at date: Date) -> String? {
    DateFormatting.clockChangeNotice(for: zone(identifier), reference: zone(reference), at: date)
}

@Suite("Clock change notice")
struct ClockChangeTests {

    @Test("Silent more than a week out")
    func quietMostOfTheYear() {
        #expect(notice("Europe/London", at: utc(10, 10, 12)) == nil)
        #expect(notice("Europe/London", at: utc(7, 1, 12)) == nil)
    }

    @Test("A zone that never changes its clocks never warns")
    func noDaylightSaving() {
        #expect(notice("Europe/Istanbul", reference: "Europe/London", at: utc(10, 22, 12)) == nil)
        #expect(notice("Asia/Tokyo", at: utc(10, 22, 12)) == nil)
    }

    @Test("Clocks going back are named, with the weekday in the zone's own terms")
    func fallBack() throws {
        let text = try #require(notice("Europe/London", at: utc(10, 20, 12)))
        #expect(text.contains("back 1h"))
        #expect(text.contains("Sun"), "25 October 2026 is a Sunday in London")
    }

    @Test("Clocks going forward read the other way round")
    func springForward() throws {
        let text = try #require(notice("America/New_York", at: utc(3, 5, 12)))
        #expect(text.contains("forward 1h"))
    }

    @Test("Tomorrow and today replace the weekday when they apply")
    func relativeDays() throws {
        #expect(try #require(notice("Europe/London", at: utc(10, 24, 12))).contains("tomorrow"))
        // 00:30 UTC on the 25th is 01:30 in London, half an hour before the change.
        #expect(try #require(notice("Europe/London", at: utc(10, 25, 0, 30))).contains("today"))
    }

    @Test("The gap to a zone that stays put is spelled out before and after")
    func gapChangesAgainstAFixedZone() throws {
        // London is 2h behind Istanbul in summer and 3h behind after the change.
        let text = try #require(notice("Europe/London", at: utc(10, 20, 12)))
        #expect(text.contains("−2h → −3h"))
    }

    @Test("Zones that change the same night keep their gap, so none is shown")
    func sameNightNoGap() throws {
        let text = try #require(notice("Europe/Paris", reference: "Europe/London", at: utc(10, 20, 12)))
        #expect(!text.contains("→"), "Paris and London move together and stay an hour apart")
    }

    @Test("Zones that change a week apart report the gap that actually shifts")
    func staggeredChanges() throws {
        // After London has already changed, New York still has a week to go:
        // the gap goes from −4h to −5h when New York changes on 1 November.
        let text = try #require(notice("America/New_York", reference: "Europe/London", at: utc(10, 27, 12)))
        #expect(text.contains("−4h → −5h"))
    }

    @Test("A half-hour shift is not rounded to an hour")
    func lordHowe() throws {
        let text = try #require(notice("Australia/Lord_Howe", at: utc(9, 30, 12)))
        #expect(text.contains("forward 30m"))
    }

    @Test("The southern hemisphere changes in the opposite season")
    func southernHemisphere() throws {
        let text = try #require(notice("Australia/Sydney", at: utc(9, 30, 12)))
        #expect(text.contains("forward 1h"), "October is spring in Sydney")
    }

    @Test("A zone compared with itself never shows a gap")
    func selfReference() throws {
        let text = try #require(notice("Europe/London", reference: "Europe/London", at: utc(10, 20, 12)))
        #expect(!text.contains("→"))
    }
}
