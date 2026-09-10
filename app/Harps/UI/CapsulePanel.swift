import AppKit

/// A plain rectangle, on purpose. PLAN.md's Phase 2 is deliberately ugly —
/// this exists to prove the loop works, not to look like anything. The real
/// capsule from design.md and motion.md is Phase 3.
///
/// What has to be right even here, because Spike A exists to prove it: this
/// panel must never take focus. `.nonactivatingPanel` plus `.accessory`
/// activation policy plus `orderFrontRegardless()` (never `makeKeyAndOrderFront`,
/// never `NSApp.activate`) is the whole trick.
///
/// `@MainActor` because it is all AppKit view work — `NSPanel`, `NSTextField`,
/// `NSView` are all main-actor types, and every caller (`HarpsController`, and
/// the transcription `Task`) is already on the main actor.
@MainActor
final class CapsulePanel {
    private let panel: NSPanel
    private let label: NSTextField

    init() {
        let rect = NSRect(x: 0, y: 0, width: 280, height: 44)
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
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]

        let view = NSView(frame: rect)
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(white: 0.08, alpha: 0.94).cgColor
        view.layer?.cornerRadius = 6

        label = NSTextField(labelWithString: "")
        label.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        label.frame = NSRect(x: 8, y: 14, width: 264, height: 16)
        view.addSubview(label)
        panel.contentView = view

        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: frame.midX - rect.width / 2, y: frame.minY + 96))
        }
    }

    func show(text: String) {
        label.stringValue = text
        panel.orderFrontRegardless()
    }

    func update(text: String) {
        label.stringValue = text
    }

    func hide() {
        panel.orderOut(nil)
    }
}
