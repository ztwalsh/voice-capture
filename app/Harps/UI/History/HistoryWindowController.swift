import AppKit
import SwiftUI

/// The window from design.md §7: 1140x720 default, remembers size and
/// position. Unlike `CapsulePanel`, this is a normal titled window that is
/// allowed to become key and to activate the app when clicked — the
/// non-activation rule in `main.swift` is specifically about the capsule
/// never stealing focus from whatever you were dictating into, and does not
/// apply to a window the user explicitly opened to read and manage their
/// own transcripts.
@MainActor
final class HistoryWindowController: NSWindowController {
    private let model: HistoryViewModel

    init(store: TranscriptStore, onOpenSetup: @escaping () -> Void = {}) {
        model = HistoryViewModel(store: store, onOpenSetup: onOpenSetup)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1140, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Harps"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        // AppKit draws its own separator under the titlebar/traffic-light
        // area by default, which showed up right alongside the header's own
        // bottom hairline as a "double divider" — one light rule is enough,
        // and it's the one the header already draws.
        window.titlebarSeparatorStyle = .none
        window.minSize = NSSize(width: 760, height: 480)
        // Confirmed live (multi-display/Spaces setup): without this, the
        // window stays parked on whichever Space was active when it was
        // first created and never follows you to the Space/display you're
        // actually looking at later — `show()`'s activation calls were all
        // succeeding, just invisibly, on a Space nobody was viewing.
        window.collectionBehavior = [.moveToActiveSpace]
        window.setFrameAutosaveName("HarpsHistoryWindow")
        window.center()
        window.contentView = NSHostingView(rootView: HistoryRootView(model: model))

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Confirmed live: `NSApp.activate(ignoringOtherApps: true)` alone does
    /// not reliably steal focus from whatever's currently frontmost when
    /// this app is `.accessory` — the reopen handler in `main.swift` (a
    /// Dock/Finder click while Harps is already running, some other app
    /// frontmost) fired correctly every time, but the window never actually
    /// came forward or took over the menu bar. Modern macOS restricts
    /// activation for background/agent apps specifically; the fix every
    /// menu-bar-plus-window app uses is to temporarily become a normal
    /// foreground app (a real Dock icon, real menu bar identity) for as
    /// long as this window is open, then drop back to `.accessory` — set
    /// once at launch in `main.swift` — the moment it closes.
    func show() {
        model.reload()
        NSApp.setActivationPolicy(.regular)
        // Confirmed live that `activate`/`makeKeyAndOrderFront` called in
        // the very same tick as the policy change brings the window
        // forward and interactive, but the *menu bar* still names whatever
        // app was previously frontmost — AppKit needs a runloop turn to
        // register the new Dock presence with the WindowServer before
        // activation can actually claim the menu bar too.
        DispatchQueue.main.async { [weak self] in
            NSApp.activate(ignoringOtherApps: true)
            self?.window?.makeKeyAndOrderFront(nil)
        }
    }
}

extension HistoryWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        AccessoryActivation.revertIfNoOtherWindowsVisible(excluding: notification.object as? NSWindow)
    }
}
