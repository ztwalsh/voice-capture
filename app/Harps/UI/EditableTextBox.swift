import AppKit
import SwiftUI

/// A fixed-height editable text box for Feedback's message field.
/// `TextEditor`'s own internal scroller ignores `.scrollIndicators(.hidden)`
/// for the same hosting-environment reason documented on `ScrollbarHider`
/// — but unlike `ScrollbarHider`'s trick (walking up to the nearest
/// `enclosingScrollView`, which only works when inserted *inside* the
/// target scroll view's own hierarchy), `TextEditor` gives no way to insert
/// anything into its internal `NSScrollView` at all: a `.background()`
/// placed on the `TextEditor` lands as a sibling in the *outer* page
/// scroll view instead, which is why that trick silently hid the wrong
/// scrollbar here. Building the `NSScrollView` directly sidesteps that —
/// there's nothing to search for since this file owns it.
struct EditableTextBox: NSViewRepresentable {
    @Binding var text: String
    let font: NSFont
    let textColor: NSColor

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.drawsBackground = false
        textView.font = font
        textView.textColor = textColor
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.delegate = context.coordinator
        textView.string = text

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView, textView.string != text else { return }
        textView.string = text
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }
    }
}
