import AppKit

/// The whole loop: hotkey down starts recording, hotkey up stops it,
/// transcribes, inserts at the caret, and appends to today's file.
///
/// Phase 3 per PLAN.md: the placeholder rectangle is now the real capsule
/// from design.md/motion.md (`CapsulePanel`/`CapsuleViewModel`), and this
/// class drives its states properly rather than pushing raw strings at a
/// label. The degenerate cases design.md's error table lists — no
/// microphone, no speech, secure input, transcription failure, insertion
/// failure — each get their own branch below instead of one generic catch.
///
/// Phase 5 adds live Accessibility monitoring rather than a one-time check
/// at launch: PLAN.md's onboarding requirement is to "recover gracefully if
/// permission is revoked later," which only means something if the app
/// also *starts* working the moment permission is granted without needing
/// a relaunch — both directions of that transition are handled by
/// `checkAccessibility()` below, polled every 2s.
///
/// `@MainActor` because it owns the panel and the hotkey monitor and is the
/// single call site for the capture types. That isolation is what lets the
/// off-main work — the audio tap and the transcription `Task` — stay small
/// and explicit rather than forcing `Sendable` plumbing through the whole app.
@MainActor
final class HarpsController {
    private let hotkey = HotkeyMonitor()
    private let recorder = AudioRecorder()
    private let transcriber: Transcriber = SpeechAnalyzerTranscriber()
    private let inserter: TextInserter = PasteTextInserter()
    private let store = TranscriptStore()
    private let panel = CapsulePanel()

    /// Below this, there almost certainly wasn't speech — a stray key tap,
    /// not a word. Matches the guard in the HTML prototypes' state machine.
    private let minimumCaptureDuration: TimeInterval = 0.35

    private var recordingURL: URL?
    private var frontmostAppName = "Unknown"
    private var startedAt = Date()

    private var isRunning = false
    private var hasPromptedForAccessibility = false
    private var permissionPollTask: Task<Void, Never>?

    /// Which trigger started the capture in progress, if any — `nil` means
    /// idle. Guards against the hotkey and the menu bar fighting over the
    /// same recorder, and lets the menu bar's click handler know whether a
    /// click should start a toggle capture or stop the one already running.
    private var activeMode: CaptureMode?

    /// `endCapture()` clears `activeMode` immediately (recording itself has
    /// stopped), but the transcription `Task` it kicks off keeps running
    /// well after that — without this separate flag, a fast double-tap (or
    /// the menu bar toggle firing right after a hotkey-driven capture ends)
    /// passes `beginCapture`'s `activeMode == nil` guard while the previous
    /// capture is still transcribing, starting a *second* concurrent
    /// `transcriber.transcribe(fileAt:)` call. Both share the one cached
    /// `SpeechTranscriber` (`SpeechAnalyzerTranscriber.prepare()` builds it
    /// once and reuses it across captures), and two live `SpeechAnalyzer`
    /// instances attaching that same module concurrently crashes inside
    /// Apple's own Speech framework (`SpeechAnalyzer.setWorkers`) — this
    /// crash was observed live and traced back to exactly that race.
    private var isTranscribing = false

    /// Set by `AppDelegate` to open the onboarding window — this class
    /// knows *when* permissions matter, not how to show onboarding UI.
    var onNeedsPermissions: (() -> Void)?

    /// design.md §5: the menu bar icon is `--live` for the entire duration
    /// of a capture, in either mode — set by `AppDelegate` to
    /// `StatusItemController.setRecording`.
    var onRecordingChanged: ((Bool) -> Void)?

    init() {
        // The capsule's own stop control only appears in toggle mode; wiring
        // it here rather than at the call site keeps `CapsulePanel` ignorant
        // of what "stop" actually means.
        panel.onStopRequested = { [weak self] in self?.stopToggleCapture() }
    }

    func start() {
        store.purgeExpired(retention: SettingsStore.shared.retention)
        checkAccessibility()
        permissionPollTask?.cancel()
        permissionPollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard let self, !Task.isCancelled else { return }
                self.checkAccessibility()
            }
        }
        // Warm the transcriber up at launch, off the critical path, so the
        // very first capture of a session doesn't also pay for building
        // `SpeechTranscriber` and checking the installed-model inventory —
        // `prepare()` is a no-op on every call after the first (see its own
        // comment), so this only ever does real work once per launch.
        Task { try? await transcriber.prepare() }
        // Same idea for the Foundation Models session `TransformEngine`
        // uses for enabled transforms — see its own comment on `warmSession`
        // for why a cold session was the real source of "slow transcription".
        Task { await TransformEngine.warmUp() }
    }

    /// design.md §5: the menu bar click toggles a capture — start on the
    /// first click, stop on the second. If a push-to-talk capture happens
    /// to be running (an edge case with no real design spec), the click is
    /// ignored rather than fighting the key you're already holding.
    func handleMenuBarToggle() {
        guard isRunning else { return }
        if let activeMode {
            if activeMode == .toggle { endCapture() }
        } else {
            beginCapture(mode: .toggle)
        }
    }

    private func stopToggleCapture() {
        guard activeMode == .toggle else { return }
        endCapture()
    }

    /// `SettingsStore.invocationMode` read fresh here, not cached — same
    /// reasoning as `HotkeyMonitor` reading `hotkey` fresh on every event:
    /// a Settings change takes effect on the very next press, no restart.
    private func handleHotkeyDown() {
        guard SettingsStore.shared.invocationMode == .holdToRecord else { return }
        beginCapture(mode: .pushToTalk)
    }

    /// In "press to start/end" mode the hotkey's key-*up* is the whole
    /// signal — a full tap, not a hold — so this reuses the exact same
    /// toggle path the menu bar click already drives rather than
    /// duplicating its start/stop logic.
    private func handleHotkeyUp() {
        switch SettingsStore.shared.invocationMode {
        case .holdToRecord: endCapture()
        case .pressToToggle: handleMenuBarToggle()
        }
    }

    private func checkAccessibility() {
        let trusted = AXIsProcessTrusted()
        if trusted, !isRunning {
            isRunning = true
            hotkey.onDown = { [weak self] in self?.handleHotkeyDown() }
            hotkey.onUp = { [weak self] in self?.handleHotkeyUp() }
            hotkey.start()
            AppLog.shared.info("Harps is running. Hold Right Option anywhere to dictate.")
        } else if !trusted, isRunning {
            isRunning = false
            hotkey.stop()
            AppLog.shared.error("Accessibility access was revoked — capture stopped.")
            panel.showError("Needs Accessibility access")
            onNeedsPermissions?()
        } else if !trusted, !hasPromptedForAccessibility {
            hasPromptedForAccessibility = true
            panel.showError("Needs Accessibility access")
            onNeedsPermissions?()
            // The SDK exposes `kAXTrustedCheckOptionPrompt` as a mutable global,
            // which Swift 6 rejects as non-concurrency-safe. Its value is the
            // stable string below, so use that directly.
            let promptKey = "AXTrustedCheckOptionPrompt" as CFString
            let opts = [promptKey: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(opts)
        }
    }

    private func beginCapture(mode: CaptureMode) {
        guard activeMode == nil, !isTranscribing else { return }
        activeMode = mode
        frontmostAppName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"

        do {
            recordingURL = try recorder.start()
            // The tap thread delivers these off the main actor, ~45 times a
            // second, from a realtime audio thread — `DispatchQueue.main.async`
            // rather than `Task { @MainActor in }` deliberately, since
            // spinning a structured-concurrency task per callback at that
            // rate from a realtime thread is exactly the kind of scheduling
            // overhead that shows up as waveform stutter.
            recorder.onLevel = { [weak self] peak in
                DispatchQueue.main.async { self?.panel.pushLevel(peak) }
            }
            panel.showListening(mode: mode)
            onRecordingChanged?(true)
        } catch {
            activeMode = nil
            AppLog.shared.error("Couldn't start recording: \(error.localizedDescription)")
            panel.showError("No microphone")
        }
    }

    private func endCapture() {
        activeMode = nil
        onRecordingChanged?(false)
        let duration = recorder.stop()
        startedAt = Date()
        guard let url = recordingURL else { return }
        recordingURL = nil

        guard duration >= minimumCaptureDuration else {
            panel.showError("Didn't catch anything")
            finishWithRecording(at: url)
            return
        }

        panel.showTranscribing()

        let appName = frontmostAppName
        isTranscribing = true
        // Explicitly on the main actor: an unstructured `Task {}` does not
        // otherwise guarantee that, and everything inside this closure —
        // the panel, and `insert(_:)`'s pasteboard and event-posting calls —
        // needs to run on the main thread.
        Task { @MainActor in
            defer { isTranscribing = false }
            do {
                try await transcriber.prepare()
                var text = try await transcriber.transcribe(fileAt: url)
                finishWithRecording(at: url)

                guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
                    panel.showError("Didn't catch anything")
                    return
                }

                // PLAN.md Phase 6: runs after transcription, before
                // insertion — the transformed text is both what gets typed
                // and what gets saved to the day file below, so Document
                // view and what actually landed at the cursor never
                // disagree. No-ops (returns `text` unchanged) if Apple
                // Intelligence isn't available, or if there are no enabled
                // transforms.
                text = await TransformEngine.apply(TransformStore.shared.enabledTransforms, to: text)

                do {
                    try inserter.insert(text)
                } catch TextInserterError.secureInputActive {
                    panel.showError("Can't type into a password field")
                    return
                } catch {
                    // design.md §5: insertion failing never loses the text —
                    // it goes to the clipboard, and the message says so.
                    AppLog.shared.error("Insertion into \(appName) failed: \(error.localizedDescription)")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    panel.showError("Copied to clipboard instead")
                    return
                }

                let elapsed = Date().timeIntervalSince(startedAt)
                _ = try? store.append(text: text, appName: appName, duration: duration)
                AppLog.shared.info(String(format: "Inserted %d words into %@ (%.2fs release-to-text)",
                                           text.split(separator: " ").count, appName, elapsed))
                // design.md §5: "Inserted" has no visual state of its own —
                // the text landing in the target app is the confirmation.
                panel.hide()
            } catch {
                AppLog.shared.error("Transcription failed: \(error.localizedDescription)")
                panel.showError("Couldn't transcribe that")
            }
        }
    }

    /// design.md's privacy posture: audio has no use after transcription
    /// and is deleted by default. `keepAudioForDebug` is the one settings
    /// row that actually changes app behavior — when it's on, the recording
    /// moves to a debug folder instead of being deleted.
    private func finishWithRecording(at url: URL) {
        guard SettingsStore.shared.keepAudioForDebug else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        let directory = SettingsStore.debugAudioDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? FileManager.default.moveItem(at: url, to: directory.appendingPathComponent(url.lastPathComponent))
    }
}
