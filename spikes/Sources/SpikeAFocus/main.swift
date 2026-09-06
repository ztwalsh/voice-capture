// Spike A — does showing the capsule move focus?
//
// The defining constraint of the whole product: if the panel steals focus, the
// caret is lost and there is nothing to insert into. This measures it rather
// than eyeballing it — frontmost app and focused element are captured before
// the panel appears and compared after it hides.
//
//   swift run SpikeAFocus
//
// Then click into a text field in another app and hold Right Option.

import AppKit
import ApplicationServices

func focusedElement() -> AXUIElement? {
    var value: CFTypeRef?
    let system = AXUIElementCreateSystemWide()
    guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &value) == .success,
          let v = value else { return nil }
    return (v as! AXUIElement)
}

func role(of element: AXUIElement?) -> String {
    guard let element else { return "none" }
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value) == .success,
          let s = value as? String else { return "unknown" }
    return s
}

final class Spike: NSObject, NSApplicationDelegate {
    private var panel: NSPanel!
    private var monitor: Any?
    private var holding = false
    private var beforeApp: String?
    private var beforeElement: AXUIElement?
    private var beforeRole = ""
    private var shownAt: CFAbsoluteTime = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(opts) else {
            print("""
            Accessibility permission is not granted.

            Grant it to the TERMINAL you are running from, not to this binary —
            a command-line tool inherits its parent's permission, and the binary
            path changes on every rebuild, which would reset it each time.

            System Settings › Privacy & Security › Accessibility › add Terminal.
            Then run again.
            """)
            NSApp.terminate(nil)
            return
        }

        buildPanel()

        // A global monitor never sees events destined for other apps as
        // "handled", so it cannot swallow the user's keystrokes.
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handle(event)
        }

        print("Ready.\n")
        print("1. Click into a text field in another app (Notes, Chrome, Slack…).")
        print("2. Hold Right Option for a second, then release.")
        print("3. Read the verdict below. Control-C to quit.\n")
    }

    private func buildPanel() {
        let rect = NSRect(x: 0, y: 0, width: 248, height: 44)
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
        view.layer?.backgroundColor = NSColor(white: 0.05, alpha: 0.92).cgColor
        view.layer?.cornerRadius = 22

        let label = NSTextField(labelWithString: "Harps — spike A")
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .white
        label.frame = NSRect(x: 20, y: 14, width: 208, height: 16)
        view.addSubview(label)
        panel.contentView = view

        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: f.midX - 124, y: f.minY + 96))
        }
    }

    private func handle(_ event: NSEvent) {
        // 61 is Right Option. Left Option is 58.
        guard event.keyCode == 61 else { return }
        let down = event.modifierFlags.contains(.option)
        if down && !holding {
            holding = true
            show()
        } else if !down && holding {
            holding = false
            hide()
        }
    }

    private func show() {
        beforeApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        beforeElement = focusedElement()
        beforeRole = role(of: beforeElement)
        shownAt = CFAbsoluteTimeGetCurrent()

        // orderFrontRegardless shows the panel without activating this app.
        // NSApp.activate must never be called anywhere in Harps.
        panel.orderFrontRegardless()
        let ms = (CFAbsoluteTimeGetCurrent() - shownAt) * 1000
        print(String(format: "  shown in %.1f ms", ms))
    }

    private func hide() {
        panel.orderOut(nil)

        let afterApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let afterElement = focusedElement()
        let afterRole = role(of: afterElement)

        let appHeld = beforeApp == afterApp
        var elementHeld = false
        if let b = beforeElement, let a = afterElement { elementHeld = CFEqual(b, a) }

        print("  before  \(beforeApp ?? "nil")  ·  \(beforeRole)")
        print("  after   \(afterApp ?? "nil")  ·  \(afterRole)")
        if appHeld && elementHeld {
            print("  PASS — frontmost app and focused element both unchanged\n")
        } else if appHeld {
            print("  PARTIAL — app held, but the focused element changed")
            print("  (some apps rebuild their AX tree; check the caret visually)\n")
        } else {
            print("  FAIL — focus moved to \(afterApp ?? "nil")\n")
        }
    }
}

let app = NSApplication.shared
// .accessory means no Dock icon and no menu bar, and it is what lets a
// non-activating panel appear without this process ever becoming frontmost.
app.setActivationPolicy(.accessory)
let delegate = Spike()
app.delegate = delegate
app.run()
