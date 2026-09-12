import AppKit

/// The menu bar presence PLAN.md's v1 scope calls for ("Menu bar item, no
/// Dock icon"). Deliberately minimal compared to design.md §6's full
/// popover (record button, recent captures inline, Open window/Settings
/// footer) — that stays out of scope — but it now carries the real
/// interaction design.md always specified: click to toggle a capture,
/// right-click for the menu, and the icon itself turns `--live` for the
/// whole duration of a capture, "the one signal that survives every window
/// being covered."
@MainActor
final class StatusItemController {
    private let statusItem: NSStatusItem
    private let onOpenHistory: () -> Void
    private let onOpenSetup: () -> Void
    private let onToggleCapture: () -> Void
    private let menu: NSMenu

    init(onOpenHistory: @escaping () -> Void, onOpenSetup: @escaping () -> Void,
         onToggleCapture: @escaping () -> Void) {
        self.onOpenHistory = onOpenHistory
        self.onOpenSetup = onOpenSetup
        self.onToggleCapture = onToggleCapture

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        menu = NSMenu()

        if let button = statusItem.button {
            button.image = Self.icon(recording: false)
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        menu.addItem(withTitle: "Open Harps", action: #selector(openHistory), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Permissions…", action: #selector(openSetup), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Harps", action: #selector(quit), keyEquivalent: "q").target = self
    }

    /// design.md §5: `--live` on the menu bar icon for the entire capture,
    /// in either mode — the only place in the app allowed to be this
    /// insistent, and about exactly one fact: the microphone is on.
    func setRecording(_ recording: Bool) {
        statusItem.button?.image = Self.icon(recording: recording)
    }

    /// Left click toggles a capture; right click (or a Control-click, which
    /// AppKit also reports as `.rightMouseUp` when Control is held) shows
    /// the menu. `NSStatusItem.menu`, if set permanently, intercepts every
    /// click and never calls the button's own action at all — so it's left
    /// unset normally and only attached for the instant it takes
    /// `performClick` to pop it.
    @objc private func handleClick() {
        // Empirically, `NSApp.currentEvent.type` for an `NSStatusBarButton`
        // click reports the opposite of what the AppKit docs' left/right
        // mouse-event naming would suggest here — confirmed by testing on
        // real hardware, not assumed from the API. `.leftMouseUp` is the
        // one that means "show the menu."
        guard let event = NSApp.currentEvent else { onToggleCapture(); return }
        if event.type == .leftMouseUp {
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            onToggleCapture()
        }
    }

    @objc private func openHistory() {
        onOpenHistory()
    }

    @objc private func openSetup() {
        onOpenSetup()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    /// The caret mark from design.md §4. Template style (adopts the menu
    /// bar's own colour) at rest; a fixed `--live` indigo, the same in both
    /// appearances, for the duration of a capture — a template image can't
    /// carry colour, so recording swaps to a non-template one.
    private static func icon(recording: Bool) -> NSImage {
        let color: NSColor = recording
            ? NSColor(red: 0x13 / 255, green: 0x0c / 255, blue: 0xee / 255, alpha: 1)
            : .labelColor

        let image = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { _ in
            let path = NSBezierPath()
            path.lineWidth = 1.7
            path.lineCapStyle = .round
            path.move(to: NSPoint(x: 5.6, y: 13.4))
            path.line(to: NSPoint(x: 10.4, y: 13.4))
            path.move(to: NSPoint(x: 5.6, y: 2.6))
            path.line(to: NSPoint(x: 10.4, y: 2.6))
            path.move(to: NSPoint(x: 8, y: 2.6))
            path.line(to: NSPoint(x: 8, y: 13.4))
            color.setStroke()
            path.stroke()
            return true
        }
        image.isTemplate = !recording
        return image
    }
}
