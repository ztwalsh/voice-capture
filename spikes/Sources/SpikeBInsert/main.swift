// Spike B — can we get text into someone else's text field?
//
// macOS offers no supported "type this into the frontmost app" call, so Harps
// needs a fallback chain. This tries each strategy against whatever you have
// focused and reports whether it landed, so Phase 0 ends with a real
// compatibility matrix instead of an assumption.
//
//   swift run SpikeBInsert                 # all three, 5s to focus something
//   swift run SpikeBInsert --strategy ax --delay 8
//
// Run it once per target app and fill in the table in ../README.md.

import AppKit
import ApplicationServices
import Carbon.HIToolbox

// MARK: - arguments

var strategies = ["ax", "paste", "type"]
var delay: UInt32 = 5
var args = Array(CommandLine.arguments.dropFirst())
while let flag = args.first {
    args.removeFirst()
    switch flag {
    case "--strategy":
        if let v = args.first, v != "all" { strategies = [v]; args.removeFirst() }
        else if !args.isEmpty { args.removeFirst() }
    case "--delay":
        if let v = args.first, let n = UInt32(v) { delay = n; args.removeFirst() }
    default:
        print("unknown flag \(flag)"); exit(1)
    }
}

// MARK: - window server registration

// Reads against the system-wide AX element (`kAXFocusedUIElementAttribute`)
// only answer for a process the window server recognises as a GUI app. A bare
// SwiftPM executable is not one until it touches NSApplication — Spike A gets
// this for free from its `NSApplicationDelegate`; this one has to ask. Without
// it every `focusedElement()` call returns nil and every strategy reports
// UNVERIFIED even in apps (Notes) that expose their fields perfectly.
let nsApp = NSApplication.shared
nsApp.setActivationPolicy(.accessory)
nsApp.finishLaunching()
RunLoop.current.run(until: Date().addingTimeInterval(0.2))

// MARK: - accessibility

let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
guard AXIsProcessTrustedWithOptions(opts) else {
    print("""
    Accessibility permission is not granted.

    Grant it to the TERMINAL you run this from, not to the binary — a CLI tool
    inherits its parent's permission, and the binary path changes on every
    rebuild, which would reset it every time.

    System Settings › Privacy & Security › Accessibility › add Terminal.
    """)
    exit(1)
}

func focusedElement() -> AXUIElement? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(AXUIElementCreateSystemWide(),
                                        kAXFocusedUIElementAttribute as CFString,
                                        &value) == .success, let v = value else { return nil }
    return (v as! AXUIElement)
}

func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success
    else { return nil }
    return value as? String
}

// MARK: - strategies

/// Cleanest when it works. Many web apps do not use native text controls and
/// fail here silently, which is the whole reason for the fallbacks.
func insertViaAX(_ text: String) -> String {
    guard let element = focusedElement() else { return "no focused element" }
    let err = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFString)
    return err == .success ? "ok" : "AXError \(err.rawValue)"
}

/// Works nearly everywhere. Clobbering the clipboard is unacceptable, so the
/// contents are saved and restored — including every type, not just the string.
func insertViaPaste(_ text: String) -> String {
    let pb = NSPasteboard.general
    var saved: [[String: Data]] = []
    for item in pb.pasteboardItems ?? [] {
        var entry: [String: Data] = [:]
        for type in item.types { entry[type.rawValue] = item.data(forType: type) }
        saved.append(entry)
    }

    pb.clearContents()
    pb.setString(text, forType: .string)

    guard let source = CGEventSource(stateID: .combinedSessionState) else { return "no event source" }
    let v = CGKeyCode(kVK_ANSI_V)
    guard let down = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: true),
          let up   = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: false)
    else { return "could not build events" }
    down.flags = .maskCommand
    up.flags = .maskCommand
    down.post(tap: .cgAnnotatedSessionEventTap)
    up.post(tap: .cgAnnotatedSessionEventTap)

    // The paste is asynchronous in the target app, so restoring immediately
    // races it. 400ms is generous; the real app should verify instead.
    Thread.sleep(forTimeInterval: 0.4)
    pb.clearContents()
    for entry in saved {
        let item = NSPasteboardItem()
        for (type, data) in entry { item.setData(data, forType: .init(type)) }
        pb.writeObjects([item])
    }
    return "ok (clipboard restored)"
}

/// Last resort. Slowest, but some apps reject both of the above.
func insertViaType(_ text: String) -> String {
    guard let source = CGEventSource(stateID: .combinedSessionState),
          let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
    else { return "could not build event" }
    var utf16 = Array(text.utf16)
    event.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
    event.post(tap: .cgAnnotatedSessionEventTap)
    if let upEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
        upEvent.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
        upEvent.post(tap: .cgAnnotatedSessionEventTap)
    }
    return "ok"
}

// MARK: - run

print("Focus a text field in the app you want to test. Starting in \(delay)s…\n")
sleep(delay)

// Secure input blocks event taps and insertion entirely. Detecting it is the
// difference between a clear error and text that silently vanishes.
if IsSecureEventInputEnabled() {
    print("SECURE INPUT IS ACTIVE — insertion cannot work here.")
    print("That is the correct answer for a password field, and Harps must say so")
    print("rather than appearing to work. Focus a normal field to test the rest.\n")
}

let app = NSWorkspace.shared.frontmostApplication
let element = focusedElement()
print("target      \(app?.localizedName ?? "unknown")  (\(app?.bundleIdentifier ?? "?"))")
print("AX role     \(element.flatMap { stringAttribute($0, kAXRoleAttribute as String) } ?? "none")")
print("readable    \(element.flatMap { stringAttribute($0, kAXValueAttribute as String) } != nil ? "yes" : "no — cannot self-verify, check the app")\n")

for name in strategies {
    let marker = "[\(name)-\(Int.random(in: 1000...9999))]"
    let before = element.flatMap { stringAttribute($0, kAXValueAttribute as String) }

    let result: String
    switch name {
    case "ax":    result = insertViaAX(marker)
    case "paste": result = insertViaPaste(marker)
    case "type":  result = insertViaType(marker)
    default:      result = "unknown strategy"
    }

    Thread.sleep(forTimeInterval: 0.35)
    let after = element.flatMap { stringAttribute($0, kAXValueAttribute as String) }

    let verdict: String
    if let after, after.contains(marker) {
        verdict = "LANDED"
    } else if before != nil && after != nil {
        verdict = "NOT FOUND in field"
    } else {
        verdict = "UNVERIFIED — look at the app"
    }
    print(String(format: "  %-6s %-24s %@", (name as NSString).utf8String!, (result as NSString).utf8String!, verdict))
    Thread.sleep(forTimeInterval: 0.5)
}

print("\nDone. Record the result in ../README.md.")
