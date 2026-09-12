import AppKit
import Foundation
import ServiceManagement

/// The system default is "follow macOS", not a fourth option — `nil` maps
/// straight onto `NSApplication.appearance`, which is how you hand control
/// back to the system after having overridden it.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

/// Auto-delete threshold for day files, checked once per launch by
/// `TranscriptStore.purgeExpired`. `never` (the default) is the safe
/// choice — deleting someone's dictation history is not something to do
/// silently unless they opted in.
enum RetentionPeriod: String, CaseIterable, Identifiable {
    case never, days30, days90, oneYear
    var id: String { rawValue }

    var label: String {
        switch self {
        case .never: return "Never"
        case .days30: return "30 days"
        case .days90: return "90 days"
        case .oneYear: return "1 year"
        }
    }

    /// `nil` means never purge.
    var days: Int? {
        switch self {
        case .never: return nil
        case .days30: return 30
        case .days90: return 90
        case .oneYear: return 365
        }
    }
}

/// PLAN.md Phase 5's settings list started out longer than what was
/// actually switchable — model and insertion strategy still have exactly
/// one implementation each, so they stay honest, informational chips in
/// Settings. Hotkey and the transcript folder later became genuine choices
/// too, alongside launch at login (`SMAppService`) and whether to keep
/// audio after transcription (debug aid; off by default per design.md's
/// privacy posture — audio has no use after transcription).
@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue else { return }
            applyLaunchAtLogin()
        }
    }

    @Published var keepAudioForDebug: Bool {
        didSet { UserDefaults.standard.set(keepAudioForDebug, forKey: Keys.keepAudio) }
    }

    /// `HotkeyMonitor` reads this fresh on every event, so changing it takes
    /// effect immediately without restarting the monitor.
    @Published var hotkey: ModifierHotkey {
        didSet { UserDefaults.standard.set(hotkey.rawValue, forKey: Keys.hotkey) }
    }

    @Published var appearance: AppAppearance {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: Keys.appearance)
            NSApp.appearance = appearance.nsAppearance
        }
    }

    @Published var retention: RetentionPeriod {
        didSet { UserDefaults.standard.set(retention.rawValue, forKey: Keys.retention) }
    }

    /// `nil` means the default `~/Library/Application Support/Harps/transcripts`.
    /// `TranscriptStore` reads this directly from `UserDefaults` rather than
    /// through this class, since it isn't itself `@MainActor` — this
    /// property exists so Settings has something to bind a picker to and to
    /// keep the persistence key in one place.
    @Published var customTranscriptsDirectory: URL? {
        didSet {
            if let customTranscriptsDirectory {
                UserDefaults.standard.set(customTranscriptsDirectory.path, forKey: Keys.transcriptsDirectory)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.transcriptsDirectory)
            }
        }
    }

    enum Keys {
        static let keepAudio = "keepAudioForDebug"
        static let hotkey = "hotkey"
        static let appearance = "appearance"
        static let retention = "retentionPeriod"
        static let transcriptsDirectory = "customTranscriptsDirectoryPath"
    }

    private init() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
        keepAudioForDebug = UserDefaults.standard.bool(forKey: Keys.keepAudio)
        hotkey = UserDefaults.standard.string(forKey: Keys.hotkey).flatMap(ModifierHotkey.init(rawValue:)) ?? .rightOption
        appearance = UserDefaults.standard.string(forKey: Keys.appearance).flatMap(AppAppearance.init(rawValue:)) ?? .system
        retention = UserDefaults.standard.string(forKey: Keys.retention).flatMap(RetentionPeriod.init(rawValue:)) ?? .never
        customTranscriptsDirectory = UserDefaults.standard.string(forKey: Keys.transcriptsDirectory)
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
        NSApp.appearance = appearance.nsAppearance
    }

    private func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            AppLog.shared.error("Couldn't change launch-at-login: \(error.localizedDescription)")
            // Reflect whatever actually happened rather than trusting the
            // toggle the user just flipped.
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    /// Where a debug recording lands when `keepAudioForDebug` is on —
    /// separate from the temp directory so it survives a reboot and is easy
    /// to find, but still clearly not part of the transcript history.
    static let debugAudioDirectory: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("Harps/debug-audio", isDirectory: true)
    }()
}
