//
//  AppLanguage.swift
//  RXZone
//

import AppKit
import Foundation

/// The language RXZone runs in, independent of the rest of the Mac.
///
/// The override is written to the app's own `AppleLanguages` default, which is
/// the mechanism macOS itself uses for per-app languages in System Settings, so
/// the two stay in agreement. It takes effect at launch, which is why changing
/// it offers a restart rather than pretending to switch live.
nonisolated enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case english = "en"
    case turkish = "tr"

    var id: String { rawValue }

    /// Shown in the language's own name, so someone who cannot read the
    /// current interface can still find theirs.
    var nativeName: String {
        switch self {
        case .system: String(localized: "System Default", comment: "Language option: follow macOS")
        case .english: "English"
        case .turkish: "Türkçe"
        }
    }

    private static let key = "AppleLanguages"

    /// The language chosen for this app alone. Reads the app's own domain only:
    /// `UserDefaults` would otherwise fall through to the Mac-wide list and
    /// report a choice the user never made here.
    static var selected: AppLanguage {
        guard let bundleID = Bundle.main.bundleIdentifier,
              let languages = UserDefaults.standard.persistentDomain(forName: bundleID)?[key] as? [String],
              let first = languages.first
        else { return .system }
        return AppLanguage.allCases.first { $0 != .system && first.hasPrefix($0.rawValue) } ?? .system
    }

    static func select(_ language: AppLanguage) {
        if language == .system {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set([language.rawValue], forKey: key)
        }
    }

    /// What the app launched with, fixed for the life of the process.
    static let launched: AppLanguage = selected

    /// Locale for every date, weekday and city name RXZone formats.
    ///
    /// Choosing a language only changes which strings the bundle loads;
    /// `Locale.current` keeps following the Mac's region and stays, say,
    /// `en_US`. Without this the interface would read "Tüm Saatleri Kopyala"
    /// beside "Friday, Aug 22". The region and its conventions are kept — only
    /// the language is swapped.
    static let locale: Locale = locale(for: launched, region: .current)

    /// `base` with only its language replaced. Separate from `locale` so the
    /// rule can be tested without relaunching anything.
    static func locale(for language: AppLanguage, region base: Locale) -> Locale {
        guard language != .system else { return base }
        var components = Locale.Components(locale: base)
        // The language components carry a region of their own; a bare "tr"
        // would replace en_US's with none and quietly drop the region's
        // conventions along with it. Carry it across explicitly.
        var chosen = Locale.Language.Components(identifier: language.rawValue)
        chosen.region = base.region
        components.languageComponents = chosen
        components.region = base.region
        return Locale(components: components)
    }

    /// Starts a fresh copy of the app and quits this one, so a new language
    /// choice takes effect without the user hunting for the quit button.
    @MainActor
    static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
            guard error == nil else { return }
            Task { @MainActor in NSApplication.shared.terminate(nil) }
        }
    }
}
