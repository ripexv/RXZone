//
//  GlobalShortcutService.swift
//  RXZone
//

import Foundation
import Observation
import AppKit
import Carbon.HIToolbox

/// The shortcuts RXZone can bind to.
///
/// A fixed set rather than a free-form recorder: capturing arbitrary key
/// combinations well needs either an event tap (which would require the
/// Accessibility permission this app deliberately avoids) or a third-party
/// recorder control. `ShortcutPreset` is the extension point — adding a case
/// here is all a richer picker would need.
nonisolated enum ShortcutPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case off
    case optionCommandT
    case controlOptionSpace
    case shiftCommandBackslash

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off: String(localized: "Off", comment: "No global shortcut")
        case .optionCommandT: "⌥⌘T"
        case .controlOptionSpace: "⌃⌥Space"
        case .shiftCommandBackslash: "⇧⌘\\"
        }
    }

    /// Virtual key code, or `nil` when no shortcut should be registered.
    var keyCode: UInt32? {
        switch self {
        case .off: nil
        case .optionCommandT: UInt32(kVK_ANSI_T)
        case .controlOptionSpace: UInt32(kVK_Space)
        case .shiftCommandBackslash: UInt32(kVK_ANSI_Backslash)
        }
    }

    /// Carbon modifier mask.
    var modifiers: UInt32 {
        switch self {
        case .off: 0
        case .optionCommandT: UInt32(optionKey | cmdKey)
        case .controlOptionSpace: UInt32(controlKey | optionKey)
        case .shiftCommandBackslash: UInt32(shiftKey | cmdKey)
        }
    }
}

/// `RXZN`, used to recognise our own hot key events.
private nonisolated let hotKeySignature: OSType = 0x5258_5A4E

/// C callback: no captures allowed, so the service arrives via `userData`.
private nonisolated let hotKeyHandler: EventHandlerUPP = { _, event, userData in
    guard let event, let userData else { return noErr }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr, hotKeyID.signature == hotKeySignature else { return noErr }

    let service = Unmanaged<GlobalShortcutService>.fromOpaque(userData).takeUnretainedValue()
    DispatchQueue.main.async {
        MainActor.assumeIsolated { service.fire() }
    }
    return noErr
}

/// Registers a system-wide hot key through Carbon's still-current
/// `RegisterEventHotKey` API.
///
/// This route needs no Accessibility permission and no event tap, which keeps
/// the app's privacy posture intact — unlike a global `NSEvent` monitor, it
/// cannot observe any keystroke other than the one it registered.
@Observable
final class GlobalShortcutService {

    private(set) var current: ShortcutPreset = .off

    var isRegistered: Bool { hotKeyRef != nil }

    @ObservationIgnored private var hotKeyRef: EventHotKeyRef?
    @ObservationIgnored private var handlerRef: EventHandlerRef?
    @ObservationIgnored private var action: (() -> Void)?

    /// Binds `preset`, replacing any previously registered combination.
    func update(to preset: ShortcutPreset, action: @escaping () -> Void) {
        self.action = action
        guard preset != current || hotKeyRef == nil else { return }
        unregister()
        current = preset

        guard let keyCode = preset.keyCode else { return }
        installHandlerIfNeeded()

        let id = EventHotKeyID(signature: hotKeySignature, id: 1)
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            preset.modifiers,
            id,
            GetApplicationEventTarget(),
            0,
            &reference
        )
        // Another app may already own the combination; leaving `hotKeyRef` nil
        // simply means RXZone does not respond to it.
        if status == noErr { hotKeyRef = reference }
    }

    fileprivate func fire() { action?() }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
    }

    /// Releases the hot key but deliberately leaves the event handler installed.
    ///
    /// Events reach us only through a registered hot key, so an idle handler
    /// never fires. Keeping it avoids tearing down and rebuilding it every time
    /// the user tries a different combination.
    private func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
}

/// Opens or closes the menu bar popover.
///
/// `MenuBarExtra` exposes no presentation binding, so the panel is toggled by
/// clicking its status item button. `NSStatusBarButton` is public API and the
/// lookup fails softly, so a future SwiftUI change can at worst make the
/// shortcut inert rather than crash the app.
enum MenuBarPresenter {
    static func toggle() {
        statusBarButton()?.performClick(nil)
    }

    private static func statusBarButton() -> NSStatusBarButton? {
        for window in NSApplication.shared.windows {
            if let button = window.contentView?.firstStatusBarButton() { return button }
        }
        return nil
    }
}

private extension NSView {
    func firstStatusBarButton() -> NSStatusBarButton? {
        if let button = self as? NSStatusBarButton { return button }
        for subview in subviews {
            if let button = subview.firstStatusBarButton() { return button }
        }
        return nil
    }
}
