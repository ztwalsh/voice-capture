import Foundation
import ServiceManagement

/// PLAN.md Phase 5's settings list is longer than what's actually
/// switchable today — hotkey, model, and insertion strategy each have
/// exactly one implementation, so making them look like pickers would be
/// dishonest UI. This holds the two settings that are genuinely real:
/// launch at login (`SMAppService`) and whether to keep audio after
/// transcription (debug aid; off by default per design.md's privacy
/// posture — audio has no use after transcription).
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

    private enum Keys {
        static let keepAudio = "keepAudioForDebug"
    }

    private init() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
        keepAudioForDebug = UserDefaults.standard.bool(forKey: Keys.keepAudio)
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
