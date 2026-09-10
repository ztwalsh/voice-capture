import AppKit

/// Watches for Right Option going down and up anywhere on the system.
///
/// A global monitor (not a local one, and not a `CGEventTap`) is the right
/// tool here: it observes events without being able to swallow them, so a
/// bug in Harps can never eat a keystroke meant for the app you're typing
/// into. `CGEventTap` can intercept and would need far more care to make
/// that same guarantee.
///
/// `@MainActor` because `NSEvent`'s global monitor delivers on the main thread
/// and the callbacks drive main-actor work (the panel, the recorder lifecycle).
@MainActor
final class HotkeyMonitor {
    private var monitor: Any?
    private var isDown = false

    var onDown: (() -> Void)?
    var onUp: (() -> Void)?

    /// Right Option's virtual key code. Left Option is 58 — deliberately not
    /// watched, so the far more commonly used left modifier stays free for
    /// every other app's shortcuts.
    private let rightOptionKeyCode: UInt16 = 61

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handle(event)
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func handle(_ event: NSEvent) {
        guard event.keyCode == rightOptionKeyCode else { return }
        let down = event.modifierFlags.contains(.option)
        if down && !isDown {
            isDown = true
            onDown?()
        } else if !down && isDown {
            isDown = false
            onUp?()
        }
    }
}
