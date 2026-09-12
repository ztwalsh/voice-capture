import AppKit
import SwiftUI

/// Plain SwiftUI `Text` + `.textSelection(.enabled)` gives native drag-select
/// and Cmd-C on macOS, but exposes no way to learn *where* the selection is
/// — which a floating toolbar anchored just below the highlighted text
/// needs. This drops to a bare `NSTextView` (non-editable, selectable only)
/// purely to get that geometry back out through `onSelectionChange`.
/// `NSTextView` is flipped (top-left origin) by default, which is exactly
/// what SwiftUI expects, so the reported rect can be used as a SwiftUI
/// offset with no coordinate-space conversion.
struct SelectableText: NSViewRepresentable {
    let text: String
    let font: NSFont
    let textColor: NSColor
    let lineSpacing: CGFloat
    var highlight: String = ""
    var onSelectionChange: (NSRange, CGRect?) -> Void = { _, _ in }

    func makeNSView(context: Context) -> AutoHeightTextView {
        let textView = AutoHeightTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.delegate = context.coordinator
        return textView
    }

    func updateNSView(_ textView: AutoHeightTextView, context: Context) {
        context.coordinator.onSelectionChange = onSelectionChange
        guard textView.attributedString().string != text
                || textView.lastHighlight != highlight
        else { return }
        textView.lastHighlight = highlight

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        let attributed = NSMutableAttributedString(string: text, attributes: [
            .font: font, .foregroundColor: textColor, .paragraphStyle: paragraph,
        ])
        // design.md §7: "Matches highlight in a warm translucent mark."
        let needle = highlight.trimmingCharacters(in: .whitespaces)
        if !needle.isEmpty {
            let nsText = text as NSString
            var searchRange = NSRange(location: 0, length: nsText.length)
            while searchRange.location < nsText.length {
                let found = nsText.range(of: needle, options: .caseInsensitive, range: searchRange)
                guard found.location != NSNotFound else { break }
                attributed.addAttribute(.backgroundColor, value: NSColor.yellow.withAlphaComponent(0.35), range: found)
                searchRange = NSRange(location: found.location + found.length, length: nsText.length - (found.location + found.length))
            }
        }
        textView.textStorage?.setAttributedString(attributed)
        textView.invalidateIntrinsicContentSize()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onSelectionChange: onSelectionChange) }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var onSelectionChange: (NSRange, CGRect?) -> Void
        init(onSelectionChange: @escaping (NSRange, CGRect?) -> Void) {
            self.onSelectionChange = onSelectionChange
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let range = textView.selectedRange()
            guard range.length > 0,
                  let layoutManager = textView.layoutManager,
                  let container = textView.textContainer
            else {
                onSelectionChange(range, nil)
                return
            }
            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            onSelectionChange(range, layoutManager.boundingRect(forGlyphRange: glyphRange, in: container))
        }
    }
}

/// Self-sizing text view: SwiftUI proposes a width (via the autoresizing
/// mask below), and this reports back whatever height the wrapped text
/// actually needs at that width, the same recipe every "NSTextView that
/// behaves like a SwiftUI Text" wrapper uses.
final class AutoHeightTextView: NSTextView {
    /// Tracks the last-applied highlight term so `updateNSView` can tell a
    /// real text change from a no-op call with the same term.
    var lastHighlight = ""

    override var intrinsicContentSize: NSSize {
        guard let layoutManager, let textContainer else { return super.intrinsicContentSize }
        layoutManager.ensureLayout(for: textContainer)
        let used = layoutManager.usedRect(for: textContainer)
        return NSSize(width: NSView.noIntrinsicMetric, height: ceil(used.height))
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        invalidateIntrinsicContentSize()
    }
}
