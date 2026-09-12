import AppKit
import SwiftUI

/// A small, non-resizable window — this is a one-time setup flow, not a
/// destination. Like the history window and unlike the capsule, this is
/// allowed to activate the app and become key: the user (or `HarpsController`
/// noticing a revoked permission) explicitly asked for it.
@MainActor
final class OnboardingWindowController: NSWindowController {
    private let model = OnboardingModel()

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Harps Setup"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        window.contentView = NSHostingView(rootView: OnboardingView(model: model, onDone: { [weak self] in
            self?.close()
        }))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
