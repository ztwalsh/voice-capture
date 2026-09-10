import AppKit

// No `@main` type on purpose — this file is named `main.swift`, so it *is*
// the entry point, which is the simplest way to build a plain AppKit agent
// app without pulling in SwiftUI's App lifecycle for a UI Harps doesn't have.
// See app/README.md for how this fits into an Xcode target.

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = HarpsController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.start()
    }
}

let app = NSApplication.shared

// No Dock icon, no menu bar, and — the important part — a process that can
// never become frontmost by accident. That is what lets `orderFrontRegardless()`
// show the panel without this app ever stealing focus from whatever you were
// typing into. `NSApp.activate` must never be called anywhere in this app.
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate
app.run()
