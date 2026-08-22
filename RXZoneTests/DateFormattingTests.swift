//
//  DateFormattingTests.swift
//  RXZoneTests
//

import Testing
import Foundation
@testable import RXZone

/// Fixed instants used throughout, chosen either side of the US/EU DST changes.
private enum Instant {
    /// 2025-01-15 12:00 UTC — northern winter.
    static let winter = Date(timeIntervalSince1970: 1_736_942_400)
    /// 2025-07-15 12:00 UTC — northern summer.
    static let summer = Date(timeIntervalSince1970: 1_752_580_800)
    /// 2025-07-15 22:00 UTC — late enough that zones straddle two dates.
    static let lateEvening = Date(timeIntervalSince1970: 1_752_616_800)
    /// 2025-12-31 23:00 UTC — straddles the new year.
    static let newYearEve = Date(timeIntervalSince1970: 1_767_222_000)
}

private func zone(_ identifier: String) -> TimeZone {
    guard let zone = TimeZone(identifier: identifier) else {
        Issue.record("Missing time zone \(identifier) in the system database")
        return .gmt
    }
    return zone
}

@Suite("Daylight saving")
struct DaylightSavingTests {

    @Test("New York shifts by an hour between winter and summer")
    func newYorkObservesDST() {
        let newYork = zone("America/New_York")
        #expect(newYork.secondsFromGMT(for: Instant.winter) == -5 * 3600)
        #expect(newYork.secondsFromGMT(for: Instant.summer) == -4 * 3600)
    }

    @Test("Istanbul stays on a fixed offset year round")
    func istanbulHasNoDST() {
        let istanbul = zone("Europe/Istanbul")
        #expect(istanbul.secondsFromGMT(for: Instant.winter) == 3 * 3600)
        #expect(istanbul.secondsFromGMT(for: Instant.summer) == 3 * 3600)
    }

    @Test("Southern hemisphere DST runs opposite to the north")
    func sydneyInvertsTheSeason() {
        let sydney = zone("Australia/Sydney")
        // January is summer in Sydney, so it is the one on daylight time.
        #expect(sydney.secondsFromGMT(for: Instant.winter) == 11 * 3600)
        #expect(sydney.secondsFromGMT(for: Instant.summer) == 10 * 3600)
    }

    @Test("Offsets follow DST rather than a cached winter value")
    func offsetLabelTracksDST() {
        let istanbul = zone("Europe/Istanbul")
        let newYork = zone("America/New_York")

        #expect(DateFormatting.offsetLabel(of: newYork, from: istanbul, at: Instant.winter) == "−8h")
        #expect(DateFormatting.offsetLabel(of: newYork, from: istanbul, at: Instant.summer) == "−7h")
    }
}

@Suite("Offset labels")
struct OffsetLabelTests {

    @Test("Half-hour zones keep their minutes")
    func halfHourOffset() {
        let label = DateFormatting.offsetLabel(
            of: zone("Asia/Kolkata"), from: zone("Europe/Istanbul"), at: Instant.summer)
        #expect(label == "+2h30m")
    }

    @Test("Quarter-hour zones keep their minutes")
    func quarterHourOffset() {
        let label = DateFormatting.offsetLabel(
            of: zone("Asia/Kathmandu"), from: zone("Europe/Istanbul"), at: Instant.summer)
        #expect(label == "+2h45m")
    }

    @Test("A zone has no offset from itself")
    func sameZone() {
        let istanbul = zone("Europe/Istanbul")
        #expect(DateFormatting.offsetLabel(of: istanbul, from: istanbul, at: Instant.summer) == "Same time")
    }

    @Test("Zones on the same offset read as identical, not as +0h")
    func distinctZonesSharingAnOffset() {
        let label = DateFormatting.offsetLabel(
            of: zone("Europe/Paris"), from: zone("Europe/Berlin"), at: Instant.summer)
        #expect(label == "Same time")
    }
}

@Suite("Calendar day differences")
struct DayDeltaTests {

    @Test("Tokyo is a day ahead of New York in the late evening UTC")
    func tokyoIsAheadOfNewYork() {
        let delta = DateFormatting.dayDelta(
            at: Instant.lateEvening, zone: zone("Asia/Tokyo"), reference: zone("America/New_York"))
        #expect(delta == 1)
    }

    @Test("The comparison is symmetric")
    func newYorkIsBehindTokyo() {
        let delta = DateFormatting.dayDelta(
            at: Instant.lateEvening, zone: zone("America/New_York"), reference: zone("Asia/Tokyo"))
        #expect(delta == -1)
    }

    @Test("Zones sharing a calendar date report no difference")
    func sameDay() {
        let delta = DateFormatting.dayDelta(
            at: Instant.lateEvening, zone: zone("Europe/Istanbul"), reference: zone("Asia/Tokyo"))
        #expect(delta == 0)
    }

    @Test("Day differences survive a year boundary")
    func acrossNewYear() {
        let delta = DateFormatting.dayDelta(
            at: Instant.newYearEve, zone: zone("Asia/Tokyo"), reference: zone("America/New_York"))
        #expect(delta == 1)
    }

    @Test("Sub-hour offsets are counted as whole days, not fractions")
    func quarterHourZone() {
        let delta = DateFormatting.dayDelta(
            at: Instant.lateEvening, zone: zone("Asia/Kathmandu"), reference: zone("America/New_York"))
        #expect(delta == 1)
    }

    @Test("Labels describe the difference in words", arguments: [
        (0, nil), (1, "Tomorrow"), (-1, "Yesterday"),
    ] as [(Int, String?)])
    func labels(delta: Int, expected: String?) {
        #expect(DateFormatting.dayDeltaLabel(delta) == expected)
    }

    @Test("Differences beyond a day are still described")
    func multiDayLabel() {
        #expect(DateFormatting.dayDeltaLabel(2) != nil)
        #expect(DateFormatting.dayDeltaLabel(-2) != nil)
    }
}

@Suite("Clock rendering")
struct ClockRenderingTests {

    @Test("A 24-hour clock pads the hour so the width stays stable")
    func twentyFourHourIsPadded() {
        let text = DateFormatting.timeString(
            for: Instant.summer, in: zone("America/New_York"), format: .twentyFourHour)
        // 12:00 UTC in July is 08:00 in New York.
        #expect(text.hasPrefix("08"))
    }

    @Test("A 12-hour clock drops the leading zero")
    func twelveHourIsUnpadded() {
        let text = DateFormatting.timeString(
            for: Instant.summer, in: zone("America/New_York"), format: .twelveHour)
        #expect(text.hasPrefix("8:"))
        // The AM/PM wording itself is the locale's business, but it must be there.
        #expect(text.count > 4)
    }

    @Test("Seconds appear only when asked for")
    func secondsAreOptional() {
        let without = DateFormatting.timeString(
            for: Instant.summer, in: zone("Europe/Istanbul"), format: .twentyFourHour)
        let with = DateFormatting.timeString(
            for: Instant.summer, in: zone("Europe/Istanbul"), format: .twentyFourHour, showsSeconds: true)
        #expect(without == "15:00")
        #expect(with.hasPrefix("15:00:"))
        #expect(with.count > without.count)
    }

    @Test("The system format renders without imposing an hour cycle")
    func systemFormatWorks() {
        let text = DateFormatting.timeString(
            for: Instant.summer, in: zone("Europe/Istanbul"), format: .system)
        #expect(!text.isEmpty)
    }

    @Test("Dates are rendered in the zone's own day, not the local one")
    func dateFollowsTheZone() {
        let tokyo = DateFormatting.dateString(for: Instant.lateEvening, in: zone("Asia/Tokyo"))
        let newYork = DateFormatting.dateString(for: Instant.lateEvening, in: zone("America/New_York"))
        #expect(tokyo != newYork)
    }
}

@Suite("Meeting summary")
struct MeetingSummaryTests {

    private var zones: [(title: String, timeZone: TimeZone)] {
        [("Istanbul", zone("Europe/Istanbul")),
         ("London", zone("Europe/London")),
         ("New York", zone("America/New_York"))]
    }

    @Test("Every zone gets a line, under a heading for the reference date")
    func listsEveryZone() {
        let text = DateFormatting.meetingSummary(
            for: zones, at: Instant.summer, reference: zone("Europe/Istanbul"), format: .twentyFourHour)
        let lines = text.split(separator: "\n")

        #expect(lines.count == 4, "One heading plus one line per zone")
        #expect(lines[1].hasPrefix("Istanbul — 15:00"))
        #expect(lines[2].hasPrefix("London — 13:00"))
        #expect(lines[3].hasPrefix("New York — 08:00"))
    }

    @Test("A zone on the same day carries no date")
    func sameDayHasNoDate() {
        let text = DateFormatting.meetingSummary(
            for: zones, at: Instant.summer, reference: zone("Europe/Istanbul"), format: .twentyFourHour)
        #expect(!text.contains("15:00 ("), "A redundant date would just be noise")
    }

    @Test("A zone on another day says so, so 00:00 is never ambiguous")
    func differentDayCarriesItsDate() {
        let text = DateFormatting.meetingSummary(
            for: [("Tokyo", zone("Asia/Tokyo"))],
            at: Instant.lateEvening,
            reference: zone("America/New_York"),
            format: .twentyFourHour)
        // 22:00 UTC is already the next morning in Tokyo but still the 15th in New York.
        #expect(text.contains("("), "The Tokyo line must spell out which day it lands on")
    }

    @Test("The summary follows the chosen clock format")
    func honoursTimeFormat() {
        let twelve = DateFormatting.meetingSummary(
            for: [("New York", zone("America/New_York"))],
            at: Instant.summer, reference: zone("America/New_York"), format: .twelveHour)
        #expect(twelve.contains("8:"))

        let twentyFour = DateFormatting.meetingSummary(
            for: [("New York", zone("America/New_York"))],
            at: Instant.summer, reference: zone("America/New_York"), format: .twentyFourHour)
        #expect(twentyFour.contains("08:00"))
    }

    @Test("An empty list still yields the date on its own")
    func emptyList() {
        let text = DateFormatting.meetingSummary(
            for: [], at: Instant.summer, reference: zone("Europe/Istanbul"), format: .system)
        #expect(!text.isEmpty)
        #expect(!text.contains("\n"))
    }
}

@Suite("Time travel labels")
struct TravelLabelTests {

    @Test("Zero reads as the present", arguments: [0])
    func zero(minutes: Int) {
        #expect(DateFormatting.travelLabel(minutes: minutes) == "Now")
    }

    @Test("Signed offsets are spelled out", arguments: [
        (195, "+3h 15m"), (120, "+2h"), (-45, "−45m"), (-90, "−1h 30m"), (1440, "+24h"),
    ] as [(Int, String)])
    func offsets(minutes: Int, expected: String) {
        #expect(DateFormatting.travelLabel(minutes: minutes) == expected)
    }
}
