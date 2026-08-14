//
//  LaunchAtLoginService.swift
//  RXZone
//

import Foundation
import Observation
import ServiceManagement

/// Wraps `SMAppService.mainApp`, the current API for login items.
///
/// Registration is owned by the system: the user can revoke it in
/// System Settings › General › Login Items at any time, so the stored truth is
/// always read back from `SMAppService` rather than from our own preferences.
@Observable
final class LaunchAtLoginService {

    private(set) var isEnabled: Bool = false

    /// Set when the last attempt failed, so the UI can explain instead of
    /// silently flipping the toggle back.
    private(set) var failureMessage: String?

    private var service: SMAppService { .mainApp }

    init() {
        refresh()
    }

    /// Re-reads the real registration state. Worth calling when Settings appears.
    func refresh() {
        isEnabled = service.status == .enabled
    }

    /// Registers or unregisters the app as a login item.
    ///
    /// Failure is expected in some situations — most commonly when running an
    /// unsigned build straight out of DerivedData — so it is reported rather
    /// than treated as a programming error.
    func setEnabled(_ enabled: Bool) {
        failureMessage = nil
        do {
            if enabled {
                // Registering while already enabled throws, so make it idempotent.
                if service.status != .enabled { try service.register() }
            } else {
                try service.unregister()
            }
        } catch {
            failureMessage = Self.explanation(for: service.status, error: error)
        }
        refresh()
    }

    private static func explanation(for status: SMAppService.Status, error: any Error) -> String {
        switch status {
        case .requiresApproval:
            String(localized: "Open System Settings › General › Login Items to allow RXZone to open at login.",
                   comment: "Login item needs user approval")
        default:
            String(localized: "Couldn’t update the login item: \(error.localizedDescription)",
                   comment: "Login item registration failed")
        }
    }
}
