//
//  ClockServiceTests.swift
//  RXZoneTests
//

import Testing
import Foundation
@testable import RXZone

@Suite("Clock scheduling")
struct ClockServiceTests {

    @Test("A fresh clock has a tick pending")
    func ticksByDefault() {
        let clock = ClockService()
        #expect(clock.isTicking)
        #expect(clock.granularity == .minute, "Minute is the cheap default")
    }

    @Test("The clock stops entirely while the display is asleep")
    func stopsOnDisplaySleep() {
        let clock = ClockService()
        clock.setDisplayAsleep(true)
        #expect(!clock.isTicking, "Nothing is visible, so nothing should wake the CPU")
    }

    @Test("Waking the display restarts the clock and re-reads the time")
    func resumesOnDisplayWake() {
        let clock = ClockService()
        clock.setDisplayAsleep(true)
        let stale = clock.now

        clock.setDisplayAsleep(false)
        #expect(clock.isTicking)
        #expect(clock.now >= stale, "The clock must be re-read before the first visible frame")
    }

    @Test("Changing tick rate while asleep does not start the clock")
    func granularityDoesNotResumeWhileAsleep() {
        let clock = ClockService()
        clock.setDisplayAsleep(true)
        clock.setGranularity(.second)
        #expect(!clock.isTicking, "A per-second rate is exactly what must not run behind a dark screen")
    }

    @Test("Repeating the same sleep state is harmless")
    func idempotent() {
        let clock = ClockService()
        clock.setDisplayAsleep(true)
        clock.setDisplayAsleep(true)
        #expect(!clock.isTicking)

        clock.setDisplayAsleep(false)
        clock.setDisplayAsleep(false)
        #expect(clock.isTicking)
    }

    @Test("Seconds cost more wake-ups than minutes, so the default stays cheap")
    func granularityIntervals() {
        #expect(ClockService.Granularity.minute.interval == 60)
        #expect(ClockService.Granularity.second.interval == 1)
        #expect(ClockService.Granularity.minute.tolerance > ClockService.Granularity.second.tolerance,
                "A generous tolerance is what lets the system coalesce the minute tick")
    }
}
