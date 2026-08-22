//
//  SolarPosition.swift
//  RXZone
//

import Foundation

/// Whether the sun is above the horizon at a place and an instant.
///
/// A fixed "night is 22:00–07:00" rule would have been three lines, but it is
/// wrong wherever the season matters: Reykjavík is bright at midnight in June
/// and dark at noon in December, and Longyearbyen spends months in each. The
/// rest of RXZone derives what it shows instead of assuming it, so this does
/// too — from the zone's own coordinates in the tz database.
///
/// Uses the low-precision solar position algorithm published by the US Naval
/// Observatory, good to about a hundredth of a degree. Far more than a sun-up
/// or sun-down answer needs.
nonisolated enum SolarPosition {

    /// Standard sunrise/sunset threshold: the sun's centre sits slightly below
    /// the horizon at the moment its upper edge appears, once atmospheric
    /// refraction and the sun's own radius are accounted for.
    private static let horizon = -0.833

    /// `nil` when the zone has no known coordinates, so callers can show
    /// nothing rather than guess.
    static func isDaylight(at date: Date, in timeZoneIdentifier: String) -> Bool? {
        guard let place = TimeZoneCoordinates.byIdentifier[timeZoneIdentifier] else { return nil }
        return elevation(at: date, latitude: place.latitude, longitude: place.longitude) > horizon
    }

    /// Sun's altitude above the horizon, in degrees. Negative means below it.
    static func elevation(at date: Date, latitude: Double, longitude: Double) -> Double {
        // Days since the J2000.0 epoch, 2000-01-01 12:00 UTC.
        let days = date.timeIntervalSince1970 / 86_400 - 10_957.5

        let meanLongitude = (280.460 + 0.985_647_4 * days).degreesNormalised
        let meanAnomaly = (357.528 + 0.985_600_3 * days).degreesNormalised.radians

        // Ecliptic longitude: the mean value corrected for the Earth's orbit
        // not being circular.
        let eclipticLongitude = (meanLongitude
            + 1.915 * sin(meanAnomaly)
            + 0.020 * sin(2 * meanAnomaly)).radians
        let obliquity = (23.439 - 0.000_000_4 * days).radians

        let rightAscension = atan2(cos(obliquity) * sin(eclipticLongitude), cos(eclipticLongitude))
        let declination = asin(sin(obliquity) * sin(eclipticLongitude))

        // Greenwich mean sidereal time, then local, then the hour angle: how
        // far the sun sits east or west of the observer's meridian.
        let greenwichSidereal = (18.697_374_558 + 24.065_709_824_419_08 * days)
            .truncatingRemainder(dividingBy: 24)
        let localSidereal = (greenwichSidereal * 15 + longitude).degreesNormalised.radians
        let hourAngle = localSidereal - rightAscension

        let latitude = latitude.radians
        let sinElevation = sin(latitude) * sin(declination)
            + cos(latitude) * cos(declination) * cos(hourAngle)
        return asin(min(max(sinElevation, -1), 1)).degrees
    }
}

private nonisolated extension Double {
    var radians: Double { self * .pi / 180 }
    var degrees: Double { self * 180 / .pi }

    /// Folded into `0..<360`, which `truncatingRemainder` alone does not do for
    /// negative values.
    var degreesNormalised: Double {
        let wrapped = truncatingRemainder(dividingBy: 360)
        return wrapped < 0 ? wrapped + 360 : wrapped
    }
}
