import AppKit
import SwiftUI

/// Hosts the real capsule from design.md/motion.md — SwiftUI content inside
/// an `NSPanel` that must never take focus. Phase 2's placeholder was a
/// plain rectangle; this is `CapsuleRootView`, but the constraint Spike A
/// exists to prove is unchanged and non-negotiable: `.nonactivatingPanel`
/// plus `.accessory` activation policy plus `orderFrontRegardless()` — never
/// `makeKeyAndOrderFront`, never `NSApp.activate` — anywhere in this file.
///
/// `@MainActor` because it is all AppKit/SwiftUI view work, same as before.
@MainActor
final class CapsulePanel {
    private let panel: NSPanel
    private let model = CapsuleViewModel()
    private var orderOutWorkItem: DispatchWorkItem?

    init() {
        let size = CapsuleRootView.contentSize
        let rect = NSRect(origin: .zero, size: size)
        panel = NSPanel(contentRect: rect,
                         styleMask: [.nonactivatingPanel, .borderless],
                         backing: .buffered,
                         defer: false)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // AppKit draws its own drop shadow shaped to the *whole window
        // rectangle* by default — 400x140, almost entirely invisible except
        // the small pill in the middle — layered underneath the capsule's
        // own SwiftUI shadow on just the pill shape. That mismatched
        // rectangular halo around empty transparent space is the "janky
        // outline" artifact. This view draws its own shadow; the system one
        // is both redundant and wrong-shaped here.
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]

        let hosting = NSHostingView(rootView: CapsuleRootView(model: model))
        hosting.frame = rect
        // `NSHostingView`'s own backing layer defaults to an opaque fill,
        // independent of the panel's own `isOpaque`/`backgroundColor` — that
        // stray opaque rectangle is what was showing as a border around the
        // capsule's shadow. Force it transparent explicitly rather than
        // relying on the panel's settings to propagate down.
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.layer?.isOpaque = false
        panel.contentView = hosting

        repositionToCursorScreen()
    }

    /// design.md §5: hotkey invocation anchors bottom centre, 92px up — but
    /// "the screen" only means one thing on a single display. On a
    /// multi-monitor setup the panel needs to follow wherever the user
    /// actually is, not whichever screen happened to be `NSScreen.main` at
    /// launch (`.main` tracks the key window, which this non-activating
    /// panel never becomes, so it stays pinned to one fixed display
    /// otherwise). The cursor's current screen is the best available proxy
    /// for "where the user is" without tracking focused-window geometry.
    private func repositionToCursorScreen() {
        let size = CapsuleRootView.contentSize
        let cursor = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(cursor) } ?? NSScreen.main
        guard let screen else { return }
        let frame = screen.visibleFrame
        // The content view carries its own bottom breathing room for the
        // shadow (see `CapsuleRootView.bottomPadding`), so the panel origin
        // only needs to place that padded box, not the capsule's true
        // baseline.
        panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2,
                                      y: frame.minY + 92 - CapsuleRootView.bottomPadding))
    }

    func showListening() {
        orderOutWorkItem?.cancel()
        repositionToCursorScreen()
        panel.orderFrontRegardless()
        model.showListening()
    }

    /// Peak amplitude 0...1 from `AudioRecorder`'s tap. No-ops outside the
    /// listening state, so a stray late callback after `stop()` is harmless.
    func pushLevel(_ peak: Float) {
        model.pushLevel(peak)
    }

    func showTranscribing() {
        model.showTranscribing()
    }

    /// Shared visual for every error condition and "didn't catch anything" —
    /// design.md §5 gives them one state. Self-dismisses after the 3s hold
    /// motion.md specifies; the caller does not need to call `hide()`.
    func showError(_ message: String) {
        orderOutWorkItem?.cancel()
        repositionToCursorScreen()
        panel.orderFrontRegardless()
        model.showError(message)
        scheduleOrderOut(after: 3.0 + 0.26)
    }

    /// A clean success: design.md's "Inserted" state has no visual — the
    /// text landing in the target app is the confirmation — so this just
    /// closes the capsule.
    func hide() {
        model.hide()
        scheduleOrderOut(after: 0.26)
    }

    private func scheduleOrderOut(after seconds: TimeInterval) {
        orderOutWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.model.settleIfHidden()
            self.panel.orderOut(nil)
        }
        orderOutWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    }
}
