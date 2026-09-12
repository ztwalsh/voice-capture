import AppKit

/// The menu bar presence PLAN.md's v1 scope calls for ("Menu bar item, no
/// Dock icon"), pulled forward from Phase 5 out of necessity — Phase 4's
/// history window needs *some* way to open it, and the hotkey alone can't
/// do that. Deliberately minimal: a caret glyph and a two-item menu, not
/// design.md §6's full popover (record button, recent captures, Open
/// window/Settings footer) — that stays Phase 5 scope.
@MainActor
final class StatusItemController {
    private let statusItem: NSStatusItem
    private let onOpenHistory: () -> Void
    private let onOpenSetup: () -> Void

    init(onOpenHistory: @escaping () -> Void, onOpenSetup: @escaping () -> Void) {
        self.onOpenHistory = onOpenHistory
        self.onOpenSetup = onOpenSetup
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let mark = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
                let path = NSBezierPath()
                path.lineWidth = 1.7
                path.lineCapStyle = .round
                path.move(to: NSPoint(x: 5.6, y: 13.4))
                path.line(to: NSPoint(x: 10.4, y: 13.4))
                path.move(to: NSPoint(x: 5.6, y: 2.6))
                path.line(to: NSPoint(x: 10.4, y: 2.6))
                path.move(to: NSPoint(x: 8, y: 2.6))
                path.line(to: NSPoint(x: 8, y: 13.4))
                NSColor.labelColor.setStroke()
                path.stroke()
                return true
            }
            mark.isTemplate = true
            button.image = mark
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Open Harps", action: #selector(openHistory), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Permissions…", action: #selector(openSetup), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Harps", action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = menu
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
}
