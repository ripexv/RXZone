# RXZone

A native macOS menu bar app for tracking several time zones at once — offline, local-only, and without a single network call.

Built with Swift and SwiftUI (`MenuBarExtra`), no third-party dependencies.

<!-- Bare URL on its own line: GitHub turns it into an inline player. Wrapping
     it in link or image syntax breaks the embed. -->

https://github.com/user-attachments/assets/45f6c1e0-5564-43c4-85c6-a281429e324c

*Several clocks in the menu bar, the popover with dates and offsets, the time travel slider, and adding a zone by searching for a city.*

## Features

- **Multiple clocks in the menu bar.** Pick any number of zones; they render side by side. New zones appear there automatically and can be unticked from the row's context menu.
- **Time travel.** A −24h … +24h slider moves every clock to the same reference instant, so you can answer "if I schedule this at 16:00, what time is it for them?" It only changes what is displayed — the system clock is never touched.
- **Correct across DST.** All offsets and calendar-day differences come from `TimeZone` and `Calendar`, so daylight saving transitions are handled by Foundation rather than by hand-written rules.
- **Full time zone database.** All 443 zones from `TimeZone.knownTimeZoneIdentifiers`, searchable by city, country, or region, with localized exemplar city names via ICU's `VVV` pattern.
- **Search by the city you actually mean.** The tz database names each zone after one representative city, so Las Vegas, Boston, Munich and İzmir do not appear in it at all. RXZone adds ~145 search aliases: searching "New Jersey" finds the right zone, says plainly that it shares New York's, and labels the row "New Jersey". Aliases only widen search — they never invent a zone, and every alias is checked against the real database at startup.
- **Custom labels and emoji** per zone, with a flag suggested automatically from the zone's region.
- **12/24-hour clock**, following the system setting by default.
- **Drag to reorder**, launch at login via `SMAppService`, and an optional global shortcut.

## Privacy

RXZone makes no network requests. That is a property of the build, not a promise:

| Check | Result |
|---|---|
| Networking symbols in source | none |
| Linked frameworks | `AppKit`, `SwiftUI`, `Foundation`, `CoreFoundation`, `ServiceManagement`, `Carbon` |
| Entitlements | `com.apple.security.app-sandbox` only |
| Network entitlement | not requested, so the sandbox blocks outbound connections |

Time zone data comes from the tz database that ships with macOS, and preferences
live in `UserDefaults` inside the sandbox container. Check it yourself:

```bash
grep -rn "URLSession\|URLRequest\|NWConnection\|analytics" RXZone --include="*.swift"
codesign -d --entitlements - /Applications/RXZone.app
```

## Requirements

macOS 14 or later. Built with Xcode 26.

## Building

```bash
xcodebuild -project RXZone.xcodeproj -scheme RXZone -configuration Release build
xcodebuild test  -project RXZone.xcodeproj -scheme RXZone -destination 'platform=macOS'
```

RXZone is an `LSUIElement` agent: no Dock icon, no main window.

95 tests aim at the parts most likely to be subtly wrong rather than the ones
easiest to reach — DST transitions in both hemispheres, calendar-day differences
across year boundaries and 45-minute offsets, clock rendering that does not
depend on the machine's locale, preference decoding from partial and malformed
payloads, and menu bar selection. Anything touching persistence uses its own
`UserDefaults` suite and never reads the real settings.

## Architecture

```
RXZone/
├── App/
│   ├── RXZoneApp.swift          MenuBarExtra + Settings scenes
│   └── AppModel.swift           @Observable state, persistence, derived rows
├── Models/
│   ├── TimeZoneItem.swift       One tracked zone (identifier + label + emoji)
│   └── Preferences.swift        Codable settings blob, resilient decoding
├── Services/
│   ├── ClockService.swift       Single boundary-aligned timer for all rows
│   ├── TimeZoneCatalog.swift    Searchable catalog built from Foundation
│   ├── LaunchAtLoginService.swift
│   └── GlobalShortcutService.swift
├── Views/                       MenuBarLabel, MenuBarView, TimeZoneRow,
│                                AddTimeZoneView, TimeTravelControl, SettingsView
└── Utilities/
    ├── DateFormatting.swift     Time/date/offset rendering
    ├── TimeZoneAliases.swift    Search aliases for places the tz database omits
    └── TimeZoneRegions.swift    Generated zone → ISO region map (flags only)
```

**One timer, not one per zone.** `ClockService` schedules a single one-shot timer
onto the next whole minute and reschedules on each fire, so it never drifts and
the process sleeps in between. It only drops to a one-second cadence while
seconds are visible, and re-reads the clock after sleep, a manual clock change,
or a time zone change.

**Preferences are one blob.** A single JSON value in `UserDefaults`, decoded key
by key with per-property fallbacks, so a payload missing a key degrades to that
key's default instead of discarding the whole configuration.

`Design/` sits outside the app target and holds the icon: layered SVGs plus
`RenderIcon.swift`, an exporter that redraws them at all ten macOS sizes.

## License

[MIT](LICENSE)
