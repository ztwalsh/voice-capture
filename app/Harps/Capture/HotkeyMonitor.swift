import AppKit

/// The small set of modifier-only triggers push-to-talk can actually use.
/// Deliberately not an arbitrary key-capture UI: the hotkey is watched via
/// `.flagsChanged`, which only ever fires for modifier keys, so anything
/// offered here has to be one. Right-side variants are the default and the
/// recommendation (PLAN.md) precisely because they're modifiers almost
/// nobody's muscle memory already claims for something else.
enum ModifierHotkey: String, CaseIterable, Identifiable, Codable {
    case rightOption, leftOption, rightCommand, rightControl, rightShift

    var id: String { rawValue }

    var label: String {
        switch self {
        case .rightOption: return "⌥ Right Option"
        case .leftOption: return "⌥ Left Option"
        case .rightCommand: return "⌘ Right Command"
        case .rightControl: return "⌃ Right Control"
        case .rightShift: return "⇧ Right Shift"
        }
    }

    /// Virtual key codes for the modifier keys `NSEvent.keyCode` reports —
    /// these are fixed hardware scan codes, not something computed.
    var keyCode: UInt16 {
        switch self {
        case .rightOption: return 61
        case .leftOption: return 58
        case .rightCommand: return 54
        case .rightControl: return 62
        case .rightShift: return 60
        }
    }

    var modifierFlag: NSEvent.ModifierFlags {
        switch self {
        case .rightOption, .leftOption: return .option
        case .rightCommand: return .command
        case .rightControl: return .control
        case .rightShift: return .shift
        }
    }
}

/// Watches for the configured modifier key going down and up anywhere on
/// the system.
///
/// A global monitor (not a `CGEventTap`) is the right tool for events sent
/// to *other* apps: it observes without being able to swallow them, so a
/// bug in Harps can never eat a keystroke meant for the app you're typing
/// into. But `addGlobalMonitorForEvents` explicitly never fires for events
/// sent to Harps' own windows (confirmed live: holding the hotkey did
/// nothing while the history window itself was frontmost — a real
/// dealbreaker, since Feedback's own text box is exactly the kind of place
/// someone would want to dictate into). A local monitor covers that other
/// half, always returning the event unchanged so it still reaches whatever
/// text field is focused — the same non-swallowing guarantee the global
/// monitor gives, just for Harps' own windows instead of everyone else's.
///
/// `@MainActor` because `NSEvent`'s monitors deliver on the main thread and
/// the callbacks drive main-actor work (the panel, the recorder lifecycle).
@MainActor
final class HotkeyMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isDown = false

    var onDown: (() -> Void)?
    var onUp: (() -> Void)?

    /// Read fresh on every event rather than cached at `start()` — lets
    /// Settings change the hotkey while a capture isn't in progress without
    /// needing to tear down and rebuild the monitor.
    private var hotkey: ModifierHotkey { SettingsStore.shared.hotkey }

    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handle(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }

    private func handle(_ event: NSEvent) {
        guard event.keyCode == hotkey.keyCode else { return }
        let down = event.modifierFlags.contains(hotkey.modifierFlag)
        if down && !isDown {
            isDown = true
            onDown?()
        } else if !down && isDown {
            isDown = false
            onUp?()
        }
    }
}
