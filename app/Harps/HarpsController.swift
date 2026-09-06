import AppKit

/// The whole loop: hotkey down starts recording, hotkey up stops it,
/// transcribes, inserts at the caret, and appends to today's file.
///
/// Phase 2 in one class on purpose — PLAN.md's exit criteria is "you dictate
/// a real sentence into a real app and the text appears," and the shortest
/// path to finding out whether that is even true is not to build the real
/// architecture first. Phase 3 is where this becomes a proper state machine
/// behind the capsule design.
final class HarpsController {
    private let hotkey = HotkeyMonitor()
    private let recorder = AudioRecorder()
    private let transcriber: Transcriber = OnDeviceTranscriber()
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
            print("""
            Accessibility permission is required and not yet granted.

            Grant it to the app you launched (or, if running via
            `swift run`/Xcode's debugger, to the parent process) under
            System Settings › Privacy & Security › Accessibility, then
            relaunch.
            """)
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
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
        startedAt = Date()

        do {
            recordingURL = try recorder.start()
            panel.show(text: "● Listening")
        } catch {
            panel.show(text: "No microphone")
            hidePanelAfterDelay()
        }
    }

    private func endCapture() {
        let duration = recorder.stop()
        guard let url = recordingURL else { return }
        recordingURL = nil

        guard duration >= minimumCaptureDuration else {
            panel.show(text: "Didn't catch anything")
            hidePanelAfterDelay()
            try? FileManager.default.removeItem(at: url)
            return
        }

        panel.update(text: "Transcribing…")

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
                    panel.update(text: "Didn't catch anything")
                    hidePanelAfterDelay()
                    return
                }

                do {
                    try inserter.insert(text)
                } catch TextInserterError.secureInputActive {
                    panel.update(text: "Can't type into a password field")
                    hidePanelAfterDelay()
                    return
                } catch {
                    panel.update(text: "Couldn't insert — check the log")
                    hidePanelAfterDelay()
                    return
                }

                let elapsed = Date().timeIntervalSince(startedAt)
                try? store.append(text: text, appName: appName, duration: duration)
                print(String(format: "Inserted %d words into %@ (%.2fs release-to-text)",
                             text.split(separator: " ").count, appName, elapsed))
                panel.hide()
            } catch {
                panel.update(text: "Couldn't transcribe that")
                hidePanelAfterDelay()
            }
        }
    }

    private func hidePanelAfterDelay(_ seconds: TimeInterval = 2.0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            self?.panel.hide()
        }
    }
}
