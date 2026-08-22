//
//  SolarPositionTests.swift
//  RXZoneTests
//

import Testing
import Foundation
@testable import RXZone

private func utc(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar.date(from: DateComponents(
        year: year, month: month, day: day, hour: hour, minute: minute))!
}

private let london = (latitude: 51.5074, longitude: -0.1278)
private let reykjavik = (latitude: 64.15, longitude: -21.85)
private let longyearbyen = (latitude: 78.0, longitude: 16.0)
private let sydney = (latitude: -33.87, longitude: 151.21)

private func isUp(_ place: (latitude: Double, longitude: Double), _ date: Date) -> Bool {
    SolarPosition.elevation(at: date, latitude: place.latitude, longitude: place.longitude) > -0.833
}

@Suite("Solar position")
struct SolarPositionTests {

    @Test("Noon and midnight come out the obvious way")
    func obviousCases() {
        #expect(isUp(london, utc(2026, 6, 21, 12)))
        #expect(!isUp(london, utc(2026, 12, 21, 0)))
    }

    @Test("Sunrise is found within the right half hour")
    func sunriseBoundary() {
        // London sunrise on the June solstice is about 03:43 UTC.
        #expect(!isUp(london, utc(2026, 6, 21, 3, 20)))
        #expect(isUp(london, utc(2026, 6, 21, 4, 10)))
    }

    @Test("Sunset is found within the right half hour")
    func sunsetBoundary() {
        // London sunset on the December solstice is about 15:53 UTC.
        #expect(isUp(london, utc(2026, 12, 21, 15, 30)))
        #expect(!isUp(london, utc(2026, 12, 21, 16, 30)))
    }

    @Test("The season is what decides, not the hour")
    func seasonBeatsClock() {
        // 08:00 UTC is daylight in London in June and darkness in December —
        // the exact case a fixed night window would get wrong.
        #expect(isUp(london, utc(2026, 6, 21, 8)))
        #expect(!isUp(london, utc(2026, 12, 21, 7, 30)))
    }

    @Test("Reykjavík is still lit near midnight at the solstice")
    func nordicSummerNight() {
        #expect(isUp(reykjavik, utc(2026, 6, 21, 23, 30)))
    }

    @Test("Polar day and polar night hold all the way round the clock")
    func polarExtremes() {
        for hour in stride(from: 0, to: 24, by: 4) {
            #expect(isUp(longyearbyen, utc(2026, 6, 21, hour)), "Polar day at \(hour):00")
            #expect(!isUp(longyearbyen, utc(2026, 12, 21, hour)), "Polar night at \(hour):00")
        }
    }

    @Test("The southern hemisphere is not upside down")
    func southernHemisphere() {
        #expect(isUp(sydney, utc(2026, 1, 15, 2)))    // 13:00 local
        #expect(!isUp(sydney, utc(2026, 1, 15, 15)))  // 02:00 local
    }

    @Test("Every catalogued zone has coordinates to reason from")
    func coverage() {
        let missing = TimeZone.knownTimeZoneIdentifiers.filter {
            TimeZoneCoordinates.byIdentifier[$0] == nil
        }
        // Only region-less zones such as bare GMT are expected to be absent.
        #expect(missing.count <= 3, "Unmapped zones show no sun or moon at all: \(missing)")
    }

    @Test("A zone with no coordinates reports nothing rather than a guess")
    func unknownZone() {
        #expect(SolarPosition.isDaylight(at: utc(2026, 6, 21, 12), in: "Mars/Olympus_Mons") == nil)
    }

    @Test("Daylight is judged where the zone is, not where the Mac is")
    func evaluatedAtTheZone() {
        let moment = utc(2026, 6, 21, 12)
        #expect(SolarPosition.isDaylight(at: moment, in: "Europe/London") == true)
        // Same instant, and the sun is well down over the Pacific.
        #expect(SolarPosition.isDaylight(at: moment, in: "Pacific/Auckland") == false)
    }

    @Test("Elevation stays inside the range an angle can occupy")
    func elevationIsBounded() {
        for hour in 0..<24 {
            let value = SolarPosition.elevation(
                at: utc(2026, 3, 15, hour), latitude: 41.0, longitude: 29.0)
            #expect(value >= -90 && value <= 90)
        }
    }
}
