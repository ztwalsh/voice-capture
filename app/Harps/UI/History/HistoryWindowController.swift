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
        window.setFrameAutosaveName("HarpsHistoryWindow")
        window.center()
        window.contentView = NSHostingView(rootView: HistoryRootView(model: model))

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        model.reload()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
