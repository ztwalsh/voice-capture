import AppKit

// No `@main` type on purpose — this file is named `main.swift`, so it *is*
// the entry point, which is the simplest way to build a plain AppKit agent
// app without pulling in SwiftUI's App lifecycle for a UI Harps doesn't have.
// See app/README.md for how this fits into an Xcode target.

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = HarpsController()
    private let onboardingWindow = OnboardingWindowController()
    private lazy var historyWindow = HistoryWindowController(
        store: TranscriptStore(),
        onOpenSetup: { [weak self] in self?.onboardingWindow.show() }
    )
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // A revoked-permission notice from `HarpsController` and the user's
        // own "Permissions…" menu item both just open this same window —
        // it always shows live state, so there's nothing more to wire up
        // for either case.
        controller.onNeedsPermissions = { [weak self] in self?.onboardingWindow.show() }
        let item = StatusItemController(
            onOpenHistory: { [weak self] in self?.historyWindow.show() },
            onOpenSetup: { [weak self] in self?.onboardingWindow.show() },
            onToggleCapture: { [weak self] in self?.controller.handleMenuBarToggle() }
        )
        statusItem = item
        controller.onRecordingChanged = { [weak item] recording in item?.setRecording(recording) }
        controller.start()
    }
}

// Registered before any window controller is constructed — several are
// created eagerly as `AppDelegate` properties, ahead of
// `applicationDidFinishLaunching`, and their SwiftUI content should never
// have a chance to resolve `Font.custom` before these are available.
FontLoader.registerBundledFonts()

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
