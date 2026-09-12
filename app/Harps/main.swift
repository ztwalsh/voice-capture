import AppKit

// No `@main` type on purpose — this file is named `main.swift`, so it *is*
// the entry point, which is the simplest way to build a plain AppKit agent
// app without pulling in SwiftUI's App lifecycle for a UI Harps doesn't have.
// See app/README.md for how this fits into an Xcode target.

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = HarpsController()
    private let historyWindow = HistoryWindowController(store: TranscriptStore())
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.start()
        statusItem = StatusItemController { [weak self] in self?.historyWindow.show() }
    }
}

let app = NSApplication.shared

// No Dock icon, no menu bar item beyond the one this app adds itself, and —
// the important part — the capture flow can never become frontmost by
// accident. That is what lets `orderFrontRegardless()` show the capsule
// without this app ever stealing focus from whatever you were typing into.
// `NSApp.activate` must never be called anywhere in `HarpsController` or
// `CapsulePanel`'s capture path. The history window is a different
// interaction — the user explicitly asked to open it — and is allowed to
// activate the app and become key normally; `.accessory` only withholds the
// Dock icon and Cmd-Tab presence, not a window's ability to take focus when
// its owning app is asked to show it.
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate
app.run()
