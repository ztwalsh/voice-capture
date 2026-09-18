import AppKit

/// Shared by `HistoryWindowController` and `OnboardingWindowController`'s
/// `windowWillClose` — both temporarily flip the app to `.regular` while
/// open (see `HistoryWindowController.show()` for why), and need to drop
/// back to `.accessory` when done. Centralized rather than each controller
/// unconditionally reverting on its own close, since if both windows
/// happen to be open at once, closing one would otherwise kill the Dock
/// icon (and the other window's ability to hold focus) out from under the
/// one still showing.
enum AccessoryActivation {
    static func revertIfNoOtherWindowsVisible(excluding closingWindow: NSWindow?) {
        let stillNeedsRegular = NSApp.windows.contains {
            $0 !== closingWindow && $0.isVisible && $0.styleMask.contains(.titled)
        }
        if !stillNeedsRegular {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
