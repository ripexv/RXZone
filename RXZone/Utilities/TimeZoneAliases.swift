//
//  TimeZoneAliases.swift
//  RXZone
//

import Foundation

/// Search aliases for places the tz database does not name.
///
/// The tz database identifies each zone by one representative city, so Las
/// Vegas, Boston, Munich and İzmir simply do not appear in it. People search by
/// the city they mean, not by the zone's representative, and come away thinking
/// the app is missing them.
///
/// This table only widens *search*. The selectable zones still come entirely
/// from `TimeZone.knownTimeZoneIdentifiers`; an alias can never invent a zone,
/// and an unknown identifier here is ignored when the catalog is built.
///
/// Where a state or country spans several zones, it maps to the one covering
/// most of its population, which is what someone typing a state name means.
nonisolated enum TimeZoneAliases {

    /// Alternative name -> canonical time zone identifier.
    static let identifierByAlias: [String: String] = [
        // MARK: United States — Eastern
        "Boston": "America/New_York", "Philadelphia": "America/New_York",
        "Miami": "America/New_York", "Atlanta": "America/New_York",
        "Washington DC": "America/New_York",
        "Baltimore": "America/New_York", "Charlotte": "America/New_York",
        "Orlando": "America/New_York", "Tampa": "America/New_York",
        "Pittsburgh": "America/New_York", "Cleveland": "America/New_York",
        "Cincinnati": "America/New_York", "Columbus": "America/New_York",
        "Buffalo": "America/New_York", "Newark": "America/New_York",
        "Jersey City": "America/New_York", "New Jersey": "America/New_York",
        "New York City": "America/New_York", "NYC": "America/New_York",
        "Manhattan": "America/New_York", "Brooklyn": "America/New_York",
        "Massachusetts": "America/New_York", "Florida": "America/New_York",
        "Virginia": "America/New_York",
        "Pennsylvania": "America/New_York", "Ohio": "America/New_York",
        "Michigan": "America/New_York", "North Carolina": "America/New_York",
        "South Carolina": "America/New_York", "Maine": "America/New_York",
        "Vermont": "America/New_York", "New Hampshire": "America/New_York",
        "Connecticut": "America/New_York", "Rhode Island": "America/New_York",
        "Delaware": "America/New_York", "Maryland": "America/New_York",
        "West Virginia": "America/New_York", "Kentucky": "America/New_York",
        "Indiana": "America/New_York", "East Coast": "America/New_York",

        // MARK: United States — Central
        "Houston": "America/Chicago", "Dallas": "America/Chicago",
        "Austin": "America/Chicago", "San Antonio": "America/Chicago",
        "Fort Worth": "America/Chicago", "New Orleans": "America/Chicago",
        "Nashville": "America/Chicago", "Memphis": "America/Chicago",
        "Milwaukee": "America/Chicago", "Minneapolis": "America/Chicago",
        "Saint Louis": "America/Chicago", "St. Louis": "America/Chicago",
        "Kansas City": "America/Chicago", "Oklahoma City": "America/Chicago",
        "Omaha": "America/Chicago", "Texas": "America/Chicago",
        "Illinois": "America/Chicago", "Wisconsin": "America/Chicago",
        "Minnesota": "America/Chicago", "Iowa": "America/Chicago",
        "Missouri": "America/Chicago", "Arkansas": "America/Chicago",
        "Louisiana": "America/Chicago", "Mississippi": "America/Chicago",
        "Alabama": "America/Chicago", "Tennessee": "America/Chicago",
        "Oklahoma": "America/Chicago", "Kansas": "America/Chicago",
        "Nebraska": "America/Chicago", "North Dakota": "America/Chicago",
        "South Dakota": "America/Chicago",

        // MARK: United States — Mountain
        "Salt Lake City": "America/Denver", "Albuquerque": "America/Denver",
        "Colorado Springs": "America/Denver",         "Colorado": "America/Denver", "Utah": "America/Denver",
        "New Mexico": "America/Denver", "Montana": "America/Denver",
        "Wyoming": "America/Denver", "Idaho": "America/Denver",
        "Arizona": "America/Phoenix", "Tucson": "America/Phoenix",

        // MARK: United States — Pacific and beyond
        "Las Vegas": "America/Los_Angeles", "Vegas": "America/Los_Angeles",
        "San Francisco": "America/Los_Angeles", "San Diego": "America/Los_Angeles",
        "Seattle": "America/Los_Angeles", "Portland": "America/Los_Angeles",
        "Sacramento": "America/Los_Angeles", "San Jose": "America/Los_Angeles",
        "Oakland": "America/Los_Angeles", "Fresno": "America/Los_Angeles",
        "Long Beach": "America/Los_Angeles", "Silicon Valley": "America/Los_Angeles",
        "California": "America/Los_Angeles", "Nevada": "America/Los_Angeles",
        "Oregon": "America/Los_Angeles", "Washington State": "America/Los_Angeles",
        "West Coast": "America/Los_Angeles",
        "Reno": "America/Los_Angeles", "Hollywood": "America/Los_Angeles",
        "Alaska": "America/Anchorage", "Hawaii": "Pacific/Honolulu",

        // MARK: Canada
        "Montreal": "America/Toronto", "Ottawa": "America/Toronto",
        "Quebec": "America/Toronto", "Ontario": "America/Toronto",
        "Calgary": "America/Edmonton", "Alberta": "America/Edmonton",
        "British Columbia": "America/Vancouver",

        // MARK: United Kingdom and Ireland
        "Manchester": "Europe/London", "Birmingham": "Europe/London",
        "Liverpool": "Europe/London", "Leeds": "Europe/London",
        "Glasgow": "Europe/London", "Edinburgh": "Europe/London",
        "Bristol": "Europe/London", "Cardiff": "Europe/London",
        "Belfast": "Europe/London", "Sheffield": "Europe/London",
        "England": "Europe/London", "Scotland": "Europe/London",
        "Wales": "Europe/London", "Northern Ireland": "Europe/London",
        "Cork": "Europe/Dublin", "Galway": "Europe/Dublin",

        // MARK: Continental Europe
        "Munich": "Europe/Berlin", "München": "Europe/Berlin",
        "Hamburg": "Europe/Berlin", "Frankfurt": "Europe/Berlin",
        "Cologne": "Europe/Berlin", "Köln": "Europe/Berlin",
        "Stuttgart": "Europe/Berlin", "Düsseldorf": "Europe/Berlin",
        "Dortmund": "Europe/Berlin", "Leipzig": "Europe/Berlin",
        "Barcelona": "Europe/Madrid", "Valencia": "Europe/Madrid",
        "Seville": "Europe/Madrid", "Sevilla": "Europe/Madrid",
        "Bilbao": "Europe/Madrid", "Malaga": "Europe/Madrid",
        "Milan": "Europe/Rome", "Milano": "Europe/Rome",
        "Naples": "Europe/Rome", "Napoli": "Europe/Rome",
        "Turin": "Europe/Rome", "Florence": "Europe/Rome",
        "Venice": "Europe/Rome", "Bologna": "Europe/Rome",
        "Lyon": "Europe/Paris", "Marseille": "Europe/Paris",
        "Toulouse": "Europe/Paris", "Nice": "Europe/Paris",
        "Bordeaux": "Europe/Paris", "Strasbourg": "Europe/Paris",
        "Rotterdam": "Europe/Amsterdam", "The Hague": "Europe/Amsterdam",
        "Den Haag": "Europe/Amsterdam", "Utrecht": "Europe/Amsterdam",
        "Geneva": "Europe/Zurich", "Basel": "Europe/Zurich",
        "Bern": "Europe/Zurich", "Salzburg": "Europe/Vienna",
        "Graz": "Europe/Vienna", "Krakow": "Europe/Warsaw",
        "Kraków": "Europe/Warsaw", "Wroclaw": "Europe/Warsaw",
        "Gdansk": "Europe/Warsaw", "Porto": "Europe/Lisbon",
        "Thessaloniki": "Europe/Athens", "Gothenburg": "Europe/Stockholm",
        "Bergen": "Europe/Oslo", "Aarhus": "Europe/Copenhagen",
        "Brno": "Europe/Prague", "Lviv": "Europe/Kyiv",
        "Kharkiv": "Europe/Kyiv", "Odessa": "Europe/Kyiv",
        "Saint Petersburg": "Europe/Moscow", "St. Petersburg": "Europe/Moscow",

        // MARK: Türkiye
        "Ankara": "Europe/Istanbul", "Izmir": "Europe/Istanbul",
        "İzmir": "Europe/Istanbul", "Antalya": "Europe/Istanbul",
        "Bursa": "Europe/Istanbul", "Adana": "Europe/Istanbul",
        "Konya": "Europe/Istanbul", "Gaziantep": "Europe/Istanbul",
        "Trabzon": "Europe/Istanbul", "Kayseri": "Europe/Istanbul",
        "Mersin": "Europe/Istanbul", "Eskisehir": "Europe/Istanbul",
        "Diyarbakir": "Europe/Istanbul", "Samsun": "Europe/Istanbul",
        "Türkiye": "Europe/Istanbul", "Turkiye": "Europe/Istanbul",

        // MARK: Middle East and Africa
        "Abu Dhabi": "Asia/Dubai", "Sharjah": "Asia/Dubai",
        "Jeddah": "Asia/Riyadh", "Mecca": "Asia/Riyadh",
        "Makkah": "Asia/Riyadh", "Medina": "Asia/Riyadh",
        "Tel Aviv": "Asia/Jerusalem", "Haifa": "Asia/Jerusalem",
        "Alexandria": "Africa/Cairo", "Giza": "Africa/Cairo",
        "Cape Town": "Africa/Johannesburg", "Durban": "Africa/Johannesburg",
        "Pretoria": "Africa/Johannesburg", "Abuja": "Africa/Lagos",
        "Kano": "Africa/Lagos", "Mombasa": "Africa/Nairobi",
        "Marrakech": "Africa/Casablanca", "Rabat": "Africa/Casablanca",

        // MARK: Asia
        "Osaka": "Asia/Tokyo", "Kyoto": "Asia/Tokyo",
        "Yokohama": "Asia/Tokyo", "Nagoya": "Asia/Tokyo",
        "Sapporo": "Asia/Tokyo", "Fukuoka": "Asia/Tokyo",
        "Kobe": "Asia/Tokyo", "Japan": "Asia/Tokyo",
        "Beijing": "Asia/Shanghai", "Peking": "Asia/Shanghai",
        "Guangzhou": "Asia/Shanghai", "Shenzhen": "Asia/Shanghai",
        "Chengdu": "Asia/Shanghai", "Tianjin": "Asia/Shanghai",
        "Wuhan": "Asia/Shanghai", "Hangzhou": "Asia/Shanghai",
        "Mumbai": "Asia/Calcutta", "Bombay": "Asia/Calcutta",
        "Delhi": "Asia/Calcutta", "New Delhi": "Asia/Calcutta",
        "Bangalore": "Asia/Calcutta", "Bengaluru": "Asia/Calcutta",
        "Hyderabad": "Asia/Calcutta", "Chennai": "Asia/Calcutta",
        "Madras": "Asia/Calcutta", "Pune": "Asia/Calcutta",
        "Ahmedabad": "Asia/Calcutta", "Jaipur": "Asia/Calcutta",
        "Busan": "Asia/Seoul", "Incheon": "Asia/Seoul",
        "Hanoi": "Asia/Ho_Chi_Minh", "Saigon": "Asia/Ho_Chi_Minh",
        "Lahore": "Asia/Karachi", "Islamabad": "Asia/Karachi",
        "Chittagong": "Asia/Dhaka", "Surabaya": "Asia/Jakarta",
        "Bandung": "Asia/Jakarta", "Bali": "Asia/Makassar",
        "Denpasar": "Asia/Makassar", "Phuket": "Asia/Bangkok",
        "Chiang Mai": "Asia/Bangkok", "Penang": "Asia/Kuala_Lumpur",
        "Cebu": "Asia/Manila", "Davao": "Asia/Manila",
        "Quezon City": "Asia/Manila",

        // MARK: Oceania
        "Canberra": "Australia/Sydney", "New South Wales": "Australia/Sydney",
        "Gold Coast": "Australia/Brisbane", "Queensland": "Australia/Brisbane",
        "Victoria": "Australia/Melbourne", "Western Australia": "Australia/Perth",
        "Wellington": "Pacific/Auckland", "Christchurch": "Pacific/Auckland",
        "New Zealand": "Pacific/Auckland",

        // MARK: Latin America
        "Rio de Janeiro": "America/Sao_Paulo", "Rio": "America/Sao_Paulo",
        "Brasilia": "America/Sao_Paulo", "Belo Horizonte": "America/Sao_Paulo",
        "Curitiba": "America/Sao_Paulo", "Porto Alegre": "America/Sao_Paulo",
        "Guadalajara": "America/Mexico_City", "Puebla": "America/Mexico_City",
        "Rosario": "America/Argentina/Buenos_Aires",
        "Valparaiso": "America/Santiago", "Medellin": "America/Bogota",
        "Cali": "America/Bogota", "Arequipa": "America/Lima",
    ]

    /// Identifier -> the aliases pointing at it, built once from the table
    /// above. Only identifiers this macOS actually knows are kept.
    static let aliasesByIdentifier: [String: [String]] = {
        // Filtered against the *known* identifiers, not merely against what
        // `TimeZone(identifier:)` resolves: the initialiser also accepts
        // historical links such as `Asia/Kolkata`, which macOS ships as
        // `Asia/Calcutta`. An alias pointing at a link would resolve fine here
        // yet never match a catalog entry, so it is dropped instead.
        let known = Set(TimeZone.knownTimeZoneIdentifiers)
        var result: [String: [String]] = [:]
        for (alias, identifier) in identifierByAlias where known.contains(identifier) {
            result[identifier, default: []].append(alias)
        }
        return result.mapValues { $0.sorted() }
    }()
}
