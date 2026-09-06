import AppKit
import Carbon.HIToolbox

enum TextInserterError: Error {
    case secureInputActive
    case couldNotSynthesizeEvents
}

/// The seam Spike B's compatibility matrix decides. Once that matrix is
/// filled in, this can grow into the documented three-strategy chain
/// (Accessibility, then paste, then synthesized keystrokes). For the walking
/// skeleton it is paste alone, because PLAN.md already calls that the
/// strategy that "works nearly everywhere" — it is the one thing here not
/// waiting on Spike B's result to be worth building.
protocol TextInserter {
    func insert(_ text: String) throws
}

/// Saves the pasteboard, writes the transcript, sends Cmd-V, restores the
/// pasteboard. Clobbering the user's clipboard is unacceptable, so every
/// pasteboard type present is saved, not just the string — a plain
/// `setString` save/restore would silently drop a copied image or file.
final class PasteTextInserter: TextInserter {
    /// How long to wait before restoring the clipboard. The paste is
    /// asynchronous in the target app; restoring immediately risks racing it
    /// and overwriting the source before the target has read it. 400ms is
    /// generous — Phase 3 should verify completion instead of guessing.
    var restoreDelay: TimeInterval = 0.4

    func insert(_ text: String) throws {
        guard !IsSecureEventInputEnabled() else { throw TextInserterError.secureInputActive }

        let pasteboard = NSPasteboard.general
        let saved = Self.snapshot(of: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        try Self.sendCommandV()

        DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) {
            Self.restore(saved, to: pasteboard)
        }
    }

    private static func snapshot(of pasteboard: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
        (pasteboard.pasteboardItems ?? []).map { item in
            var entry: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types { entry[type] = item.data(forType: type) }
            return entry
        }
    }

    private static func restore(_ saved: [[NSPasteboard.PasteboardType: Data]], to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let items = saved.map { entry -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in entry { item.setData(data, forType: type) }
            return item
        }
        if !items.isEmpty { pasteboard.writeObjects(items) }
    }

    private static func sendCommandV() throws {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            throw TextInserterError.couldNotSynthesizeEvents
        }
        let v = CGKeyCode(kVK_ANSI_V)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: false)
        else { throw TextInserterError.couldNotSynthesizeEvents }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cgAnnotatedSessionEventTap)
        up.post(tap: .cgAnnotatedSessionEventTap)
    }
}
