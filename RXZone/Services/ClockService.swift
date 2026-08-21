//
//  ClockService.swift
//  RXZone
//

import Foundation
import Observation
import AppKit

/// The app's single source of "now".
///
/// One timer drives every row, regardless of how many zones are tracked. It is
/// a one-shot timer rescheduled onto the next whole minute (or second) rather
/// than a repeating one, which keeps the display aligned with the wall clock,
/// avoids drift, and lets the process sleep between ticks.
@Observable
final class ClockService {

    enum Granularity {
        /// Wake once a minute. Used whenever no seconds are visible.
        case minute
        /// Wake once a second. Only while a view actually shows seconds.
        case second

        var interval: TimeInterval {
            switch self {
            case .minute: 60
            case .second: 1
            }
        }

        /// Allows the system to coalesce our wake-ups with other timers.
        var tolerance: TimeInterval {
            switch self {
            case .minute: 2
            case .second: 0.05
            }
        }
    }

    /// The current instant, republished on every tick.
    private(set) var now: Date = .init()

    /// The Mac's own time zone. Re-read when the system reports a change.
    private(set) var localTimeZone: TimeZone = .current

    private(set) var granularity: Granularity = .minute

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var observers: [any NSObjectProtocol] = []

    init() {
        observeSystemChanges()
        schedule()
    }

    deinit {
        timer?.invalidate()
        // Captured locally so no `self` is touched during deinitialization.
        let tokens = observers
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        for token in tokens {
            NotificationCenter.default.removeObserver(token)
            workspaceCenter.removeObserver(token)
        }
    }

    /// Switches tick rate. Cheap and idempotent, so views can call it freely
    /// as they appear and disappear.
    func setGranularity(_ granularity: Granularity) {
        guard granularity != self.granularity else { return }
        self.granularity = granularity
        refresh()
    }

    /// Re-reads the clock immediately and realigns the next tick.
    func refresh() {
        now = Date()
        localTimeZone = .current
        schedule()
    }

    /// Whether a tick is currently pending.
    var isTicking: Bool { timer != nil }

    /// Stops the clock while nothing it draws can be seen, and starts it again
    /// on wake. Ticking through a display sleep costs battery for a status item
    /// nobody is looking at — a full second-granularity tick rate is the worst
    /// case, and that is exactly when a Mac is most likely to be on battery.
    func setDisplayAsleep(_ asleep: Bool) {
        guard asleep != isDisplayAsleep else { return }
        isDisplayAsleep = asleep
        // `refresh()` on wake re-reads the clock before the first visible frame,
        // so the pause can never surface as a stale time.
        asleep ? schedule() : refresh()
    }

    @ObservationIgnored private var isDisplayAsleep = false

    // MARK: - Timer

    private func schedule() {
        timer?.invalidate()
        timer = nil

        // Do not wake the CPU for a screen that is off.
        guard !isDisplayAsleep else { return }

        let interval = granularity.interval
        let elapsed = Date().timeIntervalSinceReferenceDate
        // Land just after the boundary so the freshly read time is the new minute.
        let boundary = (elapsed / interval).rounded(.down) * interval + interval
        let delay = max(0.01, boundary - elapsed + 0.01)

        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.now = Date()
                self.schedule()
            }
        }
        timer.tolerance = granularity.tolerance
        // `.common` keeps the clock running while a menu or popover is tracking.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    // MARK: - System changes

    /// Waking from sleep, a manual clock change or a travel-induced time zone
    /// change all invalidate both the displayed time and the pending tick.
    private func observeSystemChanges() {
        let center = NotificationCenter.default
        let handler: @Sendable (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                DateFormatting.invalidateLocaleCache()
                self.refresh()
            }
        }

        observers.append(center.addObserver(
            forName: .NSSystemClockDidChange, object: nil, queue: .main, using: handler))
        observers.append(center.addObserver(
            forName: .NSSystemTimeZoneDidChange, object: nil, queue: .main, using: handler))
        observers.append(center.addObserver(
            forName: NSLocale.currentLocaleDidChangeNotification, object: nil, queue: .main, using: handler))
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main, using: handler))

        // The display sleeps on its own well before the machine does, so this is
        // a separate and far more frequent signal than system sleep.
        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(workspace.addObserver(
            forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.setDisplayAsleep(true) }
        })
        observers.append(workspace.addObserver(
            forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.setDisplayAsleep(false) }
        })
    }
}
