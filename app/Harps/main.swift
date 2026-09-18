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
        NSApp.mainMenu = Self.makeMainMenu()

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

        // Clicking the Dock/Finder icon on a *cold* launch (Harps wasn't
        // already running) never goes through `applicationShouldHandleReopen`
        // below — that only fires for an already-running app. Without this,
        // a cold launch left `.accessory`'s policy in place and never became
        // the frontmost app, so the menu bar kept showing whatever was
        // frontmost before — indistinguishable from "nothing happened" to
        // the user clicking the icon. Showing the window here covers that
        // case the same way `applicationShouldHandleReopen` covers reopen.
        historyWindow.show()
    }

    /// Fires when the user double-clicks `Harps.app` again in Finder/Applications
    /// (or a Dock tile, if someone drags one there) while it's already
    /// running — PLAN.md Phase 7. `.accessory` activation policy only
    /// withholds the Dock tile and Cmd-Tab presence, not this callback, so
    /// this fires regardless of there being a Dock icon to click.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        historyWindow.show()
        return true
    }

    /// Confirmed live (screenshot in hand): with no `NSApp.mainMenu` at
    /// all — true for this whole app until now, since it's a bare AppKit
    /// agent with no Xcode-generated menu bar — activating and bringing a
    /// window forward still left the *previous* app's own File/Edit/Window
    /// menu items showing in the menu bar. macOS has nothing of Harps' own
    /// to display there without this, so it just leaves whatever was
    /// already up. A minimal menu (just Quit, really) is enough to give it
    /// something.
    private static func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(
            withTitle: "About Harps",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Quit Harps",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        // Standard Cmd-C/V/X/A/Z bindings — without these, text fields in
        // the history window (search, the Feedback box, Transform editor)
        // silently lose the usual edit shortcuts once a real menu bar is
        // present, since AppKit normally wires them through the Edit menu.
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        return mainMenu
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
