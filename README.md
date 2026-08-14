# RXZone

A native macOS menu bar app for tracking several time zones at once — offline, local-only, and without a single network call.

Built with Swift and SwiftUI (`MenuBarExtra`), no third-party dependencies.

## Features

- **Multiple clocks in the menu bar.** Pick any number of zones; they render side by side. New zones appear there automatically and can be unticked from the row's context menu.
- **Time travel.** A −24h … +24h slider moves every clock to the same reference instant, so you can answer "if I schedule this at 16:00, what time is it for them?" It only changes what is displayed — the system clock is never touched.
- **Correct across DST.** All offsets and calendar-day differences come from `TimeZone` and `Calendar`, so daylight saving transitions are handled by Foundation rather than by hand-written rules.
- **Full time zone database.** All 443 zones from `TimeZone.knownTimeZoneIdentifiers`, searchable by city, country, or region, with localized exemplar city names via ICU's `VVV` pattern.
- **Custom labels and emoji** per zone, with a flag suggested automatically from the zone's region.
- **12/24-hour clock**, following the system setting by default.
- **Drag to reorder**, launch at login via `SMAppService`, and an optional global shortcut.

## Privacy

RXZone does no networking. This is a property of the build, not just a promise:

| Check | Result |
|---|---|
| Networking symbols in source (`URLSession`, sockets, WebSocket, analytics SDKs) | none |
| Linked frameworks | `AppKit`, `SwiftUI`, `Foundation`, `CoreFoundation`, `ServiceManagement`, `Carbon` |
| Entitlements | `com.apple.security.app-sandbox` only |
| Network entitlement | not requested — outbound connections are blocked by the sandbox |

All time zone data comes from the tz database that ships with macOS. Preferences live in `UserDefaults` inside the app's sandbox container. Nothing is collected, logged, or transmitted.

Reproduce the audit yourself:

```bash
grep -rn "URLSession\|URLRequest\|NWConnection\|analytics" RXZone --include="*.swift"
codesign -d --entitlements - /Applications/RXZone.app
```

## Requirements

- macOS 26.5 or later (see note below)
- Xcode 26

The deployment target is set to the latest macOS. Every API used is available from macOS 14, so lowering `MACOSX_DEPLOYMENT_TARGET` to `14.0` widens compatibility without code changes.

## Building

```bash
xcodebuild -project RXZone.xcodeproj -scheme RXZone -configuration Release build
```

The app is an `LSUIElement` agent: it has no Dock icon and no main window.

## Tests

```bash
xcodebuild test -project RXZone.xcodeproj -scheme RXZone -destination 'platform=macOS'
```

71 tests written with Swift Testing, covering the parts most likely to be subtly
wrong rather than the parts easiest to reach:

- **Daylight saving** — New York shifting an hour between January and July, Sydney inverting the season, Istanbul holding a fixed offset, and offset labels tracking the date rather than a cached value.
- **Calendar day differences** — zones a day apart, across a year boundary, and with 45-minute offsets, where naive elapsed-time maths gives the wrong answer.
- **Clock rendering** — 24-hour padding, 12-hour without a leading zero, seconds only when requested. Assertions avoid locale-specific wording so they hold on any machine.
- **Preference decoding** — empty, partial, and malformed payloads, plus unknown enum cases, all falling back per-key instead of discarding the configuration.
- **Menu bar selection** — auto-adding new zones, keeping the local clock when the first zone is added, clearing orphaned ids on delete, and never leaving the status item blank.
- **Catalog** — parity with `TimeZone.knownTimeZoneIdentifiers`, diacritic-insensitive search, prefix ranking, and flag derivation.

Each test that touches persistence uses its own `UserDefaults` suite, so the
suite never reads or writes the real app's settings.

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
    └── TimeZoneRegions.swift    Generated zone → ISO region map (flags only)
```

Two design points worth calling out:

**One timer, not one per zone.** `ClockService` schedules a single one-shot timer onto the next whole minute and reschedules on each fire. It never drifts, lets the process sleep in between, and only drops to a one-second cadence while seconds are actually visible. Waking from sleep, a manual clock change, and time zone changes all trigger a re-read.

**Preferences are one blob.** Everything persists as a single JSON value in `UserDefaults`, decoded key-by-key with per-property fallbacks. A payload missing a key degrades to that key's default instead of throwing away the whole configuration, and an unreadable blob resets cleanly to working defaults.
