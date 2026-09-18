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
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Harps Setup"
        window.isReleasedWhenClosed = false
        // Same fix as `HistoryWindowController`: without this the window
        // stays parked on whichever Space was active at creation time and
        // never follows you to whatever Space/display you're actually on.
        window.collectionBehavior = [.moveToActiveSpace]
        window.center()
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Decided fresh on every call rather than once at init — this
    /// controller is built once at launch, but `show()` can be called again
    /// later in the same run (`HarpsController` reopens it if Accessibility
    /// gets revoked mid-session). Re-checking here means completing the
    /// first-run wizard earlier in the same session correctly downgrades a
    /// later reopen to the plain checklist instead of restarting the whole
    /// welcome story.
    func show() {
        let isFirstRun = !OnboardingModel.hasCompletedOnboarding
        let onDone: () -> Void = { [weak self] in self?.close() }
        if isFirstRun {
            window?.setContentSize(NSSize(width: 460, height: 400))
            window?.contentView = NSHostingView(rootView: OnboardingWizardView(model: model, onDone: onDone))
        } else {
            window?.setContentSize(NSSize(width: 460, height: 360))
            window?.contentView = NSHostingView(rootView: OnboardingView(model: model, onDone: onDone))
        }
        // Same fix as `HistoryWindowController.show()`, including the
        // runloop-turn deferral: without it the window comes forward but
        // the menu bar keeps naming whatever app was previously frontmost.
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async { [weak self] in
            NSApp.activate(ignoringOtherApps: true)
            self?.window?.makeKeyAndOrderFront(nil)
        }
    }
}

extension OnboardingWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        AccessoryActivation.revertIfNoOtherWindowsVisible(excluding: notification.object as? NSWindow)
    }
}
