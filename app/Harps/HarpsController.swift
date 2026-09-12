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

    func start() {
        guard AXIsProcessTrusted() else {
            panel.showError("Needs Accessibility access")
            print("""
            Accessibility permission is required and not yet granted.

            Grant it to the app you launched (or, if running via
            `swift run`/Xcode's debugger, to the parent process) under
            System Settings › Privacy & Security › Accessibility, then
            relaunch.
            """)
            // The SDK exposes `kAXTrustedCheckOptionPrompt` as a mutable global,
            // which Swift 6 rejects as non-concurrency-safe. Its value is the
            // stable string below, so use that directly.
            let promptKey = "AXTrustedCheckOptionPrompt" as CFString
            let opts = [promptKey: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(opts)
            return
        }

        hotkey.onDown = { [weak self] in self?.beginCapture() }
        hotkey.onUp = { [weak self] in self?.endCapture() }
        hotkey.start()
        print("Harps is running. Hold Right Option anywhere to dictate.")
    }

    private func beginCapture() {
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
            panel.showListening()
        } catch {
            panel.showError("No microphone")
        }
    }

    private func endCapture() {
        let duration = recorder.stop()
        startedAt = Date()
        guard let url = recordingURL else { return }
        recordingURL = nil

        guard duration >= minimumCaptureDuration else {
            panel.showError("Didn't catch anything")
            try? FileManager.default.removeItem(at: url)
            return
        }

        panel.showTranscribing()

        let appName = frontmostAppName
        // Explicitly on the main actor: an unstructured `Task {}` does not
        // otherwise guarantee that, and everything inside this closure —
        // the panel, and `insert(_:)`'s pasteboard and event-posting calls —
        // needs to run on the main thread.
        Task { @MainActor in
            do {
                try await transcriber.prepare()
                let text = try await transcriber.transcribe(fileAt: url)
                try? FileManager.default.removeItem(at: url)

                guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
                    panel.showError("Didn't catch anything")
                    return
                }

                do {
                    try inserter.insert(text)
                } catch TextInserterError.secureInputActive {
                    panel.showError("Can't type into a password field")
                    return
                } catch {
                    // design.md §5: insertion failing never loses the text —
                    // it goes to the clipboard, and the message says so.
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    panel.showError("Copied to clipboard instead")
                    return
                }

                let elapsed = Date().timeIntervalSince(startedAt)
                _ = try? store.append(text: text, appName: appName, duration: duration)
                print(String(format: "Inserted %d words into %@ (%.2fs release-to-text)",
                             text.split(separator: " ").count, appName, elapsed))
                // design.md §5: "Inserted" has no visual state of its own —
                // the text landing in the target app is the confirmation.
                panel.hide()
            } catch {
                panel.showError("Couldn't transcribe that")
            }
        }
    }
}
