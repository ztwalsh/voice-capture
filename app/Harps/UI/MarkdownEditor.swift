import AppKit
import SwiftUI

/// A formatting action the toolbar requests, applied directly to the
/// underlying `NSTextView`'s live selection — the plain `text` binding has
/// no notion of selection/cursor position, so formatting can't go through
/// it the way a plain string edit would.
enum MarkdownFormatCommand {
    case heading(Int) // 1...3
    case bold
    case italic
    case code
    case bulletList
    case numberedList
}

/// Dispatches toolbar commands straight to whichever `NSTextView` is
/// currently on screen, bypassing SwiftUI's own state/update cycle. A
/// plain method call invoked the instant a button is tapped, rather than
/// a `Binding` polled from `updateNSView`.
private final class MarkdownEditorCommandBus {
    var handler: ((MarkdownFormatCommand) -> Void)?
    func send(_ command: MarkdownFormatCommand) { handler?(command) }
}

/// Converts between the plain Markdown string this app actually saves and
/// a real `NSAttributedString` for Rich Text mode. Rich Text never contains
/// a literal "#"/"**"/"_"/"`" character — those are parsed away entirely
/// and replaced with real font traits (bold/italic/monospace/heading
/// size), and list lines get a real "•\t"/"1.\t" prefix instead of "- "/
/// "1. ". `markdown(from:)` walks the same attributed content back into
/// Markdown syntax for saving — this is the one and only place Markdown
/// syntax gets reconstructed for Rich Text, so there's never a stray
/// literal marker left sitting in the editable text to render oddly or
/// pile up on repeat edits.
private enum MarkdownRichConversion {
    static func codeFont(basedOn font: NSFont) -> NSFont {
        NSFont(name: "GeistMono-Regular", size: max(font.pointSize - 0.5, 8))
            ?? .monospacedSystemFont(ofSize: max(font.pointSize - 0.5, 8), weight: .regular)
    }

    /// Neither `NSFontManager.convert(_:toHaveTrait:)` nor setting
    /// `.bold`/`.italic` directly on the font *descriptor* actually
    /// rendered differently for Geist — both rely on AppKit finding or
    /// synthesizing a variant, and empirically neither did anything
    /// visible for this font. This instead swaps in an *actually bundled*
    /// heavier weight by name — "Geist-SemiBold" (already used for the
    /// app's own headers elsewhere) — which is guaranteed to look
    /// different because it's a genuinely different font file, no
    /// synthesis involved. Falls back to the font unchanged only if even
    /// that named font can't be found.
    static func boldVariant(of font: NSFont) -> NSFont {
        let boldName = font.fontName.replacingOccurrences(of: "Regular", with: "SemiBold")
        return NSFont(name: boldName, size: font.pointSize) ?? NSFont(name: "Geist-SemiBold", size: font.pointSize) ?? font
    }

    static func regularVariant(of font: NSFont) -> NSFont {
        let regularName = font.fontName
            .replacingOccurrences(of: "SemiBold", with: "Regular")
            .replacingOccurrences(of: "Medium", with: "Regular")
        return NSFont(name: regularName, size: font.pointSize) ?? font
    }

    static func isBold(_ font: NSFont) -> Bool {
        font.fontName.contains("SemiBold") || font.fontName.contains("Bold")
    }

    /// Italic has no real bundled weight at all (not even one to swap in
    /// like Bold's SemiBold), so this uses `.obliqueness` — a plain
    /// render-time skew the text system applies to any font regardless of
    /// whether it has a true italic variant. Independent of font identity,
    /// so it's tracked as its own attribute rather than folded into the
    /// bold/regular font-swapping above.
    static let italicObliqueness: Double = 0.2

    static func headingFont(level: Int, baseFont: NSFont) -> NSFont {
        let size: CGFloat = level == 1 ? 20 : level == 2 ? 17 : 15
        let sized = NSFontManager.shared.convert(baseFont, toSize: size)
        return boldVariant(of: sized)
    }

    static func attributed(from markdown: String, baseFont: NSFont, textColor: NSColor) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = markdown.components(separatedBy: "\n")
        for (index, rawLine) in lines.enumerated() {
            result.append(line(rawLine, baseFont: baseFont, textColor: textColor))
            if index != lines.count - 1 {
                result.append(NSAttributedString(string: "\n", attributes: [.font: baseFont, .foregroundColor: textColor]))
            }
        }
        if result.length == 0 {
            result.append(NSAttributedString(string: "", attributes: [.font: baseFont, .foregroundColor: textColor]))
        }
        return result
    }

    private static func line(_ rawLine: String, baseFont: NSFont, textColor: NSColor) -> NSAttributedString {
        for level in [3, 2, 1] {
            let prefix = String(repeating: "#", count: level) + " "
            if rawLine.hasPrefix(prefix) {
                let content = String(rawLine.dropFirst(prefix.count))
                let font = headingFont(level: level, baseFont: baseFont)
                return NSAttributedString(string: content, attributes: [.font: font, .foregroundColor: textColor])
            }
        }

        var body = rawLine
        let result = NSMutableAttributedString()
        var isListItem = false
        if body.hasPrefix("- ") {
            body = String(body.dropFirst(2))
            result.append(NSAttributedString(string: "•\t", attributes: [.font: baseFont, .foregroundColor: textColor]))
            isListItem = true
        } else if let dotRange = body.range(of: ". "), Int(body[body.startIndex..<dotRange.lowerBound]) != nil {
            let marker = String(body[body.startIndex..<dotRange.lowerBound]) + ".\t"
            body = String(body[dotRange.upperBound...])
            result.append(NSAttributedString(string: marker, attributes: [.font: baseFont, .foregroundColor: textColor]))
            isListItem = true
        }
        result.append(inline(body, font: baseFont, textColor: textColor))
        if isListItem { applyListIndent(to: result) }
        return result
    }

    /// A hanging indent — the marker sits at the paragraph's true left
    /// edge, the tab jumps to `listIndent`, and (this is the part that was
    /// missing) any wrapped continuation line also indents to
    /// `listIndent`, instead of falling back to the far-left margin like a
    /// plain paragraph. `tabStops` is what actually places the tab stop;
    /// `headIndent` is what wrapped lines obey.
    static let listIndent: CGFloat = 20

    static func applyListIndent(to attributed: NSMutableAttributedString) {
        let style = NSMutableParagraphStyle()
        style.firstLineHeadIndent = 0
        style.headIndent = listIndent
        style.tabStops = [NSTextTab(textAlignment: .left, location: listIndent)]
        attributed.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: attributed.length))
    }

    /// Parses `**bold**`/`_italic_`/`` `code` `` within one line into real
    /// runs, always resolving whichever pattern's match starts earliest
    /// (rather than checking bold/code/italic in a fixed order regardless
    /// of position) so formatting comes out in the order it actually
    /// appears in the source.
    private enum InlineKind { case bold, code, italic }

    private static func inline(_ raw: String, font: NSFont, textColor: NSColor) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var remaining = Substring(raw)
        let bold = boldVariant(of: font)
        let mono = codeFont(basedOn: font)

        func plain(_ s: Substring) -> NSAttributedString {
            NSAttributedString(string: String(s), attributes: [.font: font, .foregroundColor: textColor])
        }

        while !remaining.isEmpty {
            let boldRange = remaining.range(of: #"\*\*(.+?)\*\*"#, options: .regularExpression)
            let codeRange = remaining.range(of: "`([^`]+?)`", options: .regularExpression)
            let italicRange = remaining.range(of: "_(.+?)_", options: .regularExpression)
            let candidates: [(Range<Substring.Index>, InlineKind, Int)] = [
                boldRange.map { ($0, InlineKind.bold, 2) },
                codeRange.map { ($0, InlineKind.code, 1) },
                italicRange.map { ($0, InlineKind.italic, 1) },
            ].compactMap { $0 }

            guard let earliest = candidates.min(by: { $0.0.lowerBound < $1.0.lowerBound }) else {
                result.append(plain(remaining))
                break
            }
            let (range, kind, markerLength) = earliest
            result.append(plain(remaining[remaining.startIndex..<range.lowerBound]))
            let inner = String(remaining[range].dropFirst(markerLength).dropLast(markerLength))
            switch kind {
            case .bold:
                result.append(NSAttributedString(string: inner, attributes: [.font: bold, .foregroundColor: textColor]))
            case .code:
                result.append(NSAttributedString(string: inner, attributes: [.font: mono, .foregroundColor: textColor]))
            case .italic:
                result.append(NSAttributedString(string: inner, attributes: [
                    .font: font, .foregroundColor: textColor, .obliqueness: italicObliqueness,
                ]))
            }
            remaining = remaining[range.upperBound...]
        }
        if result.length == 0 { result.append(plain("")) }
        return result
    }

    static func markdown(from attributed: NSAttributedString, baseFont: NSFont) -> String {
        let full = attributed.string as NSString
        guard full.length > 0 else { return "" }
        var result = ""
        var location = 0
        var firstParagraph = true
        while location <= full.length {
            guard location < full.length else { break }
            let lineRange = full.lineRange(for: NSRange(location: location, length: 0))
            let endsWithNewline = full.substring(with: NSRange(location: NSMaxRange(lineRange) - 1, length: 1)) == "\n"
            let contentRange = endsWithNewline
                ? NSRange(location: lineRange.location, length: lineRange.length - 1)
                : lineRange

            if !firstParagraph { result += "\n" }
            firstParagraph = false
            result += paragraphMarkdown(attributed, range: contentRange, baseFont: baseFont)

            location = NSMaxRange(lineRange)
            if !endsWithNewline { break }
        }
        return result
    }

    private static func paragraphMarkdown(_ attributed: NSAttributedString, range: NSRange, baseFont: NSFont) -> String {
        guard range.length > 0 else { return "" }
        let full = attributed.string as NSString

        if let firstFont = attributed.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont,
           isBold(firstFont),
           firstFont.pointSize > baseFont.pointSize + 0.5 {
            var uniform = true
            attributed.enumerateAttribute(.font, in: range, options: []) { value, _, stop in
                guard let f = value as? NSFont, abs(f.pointSize - firstFont.pointSize) < 0.01,
                      isBold(f)
                else { uniform = false; stop.pointee = true; return }
            }
            if uniform {
                let prefix = firstFont.pointSize >= 19 ? "# " : (firstFont.pointSize >= 16.5 ? "## " : "### ")
                return prefix + full.substring(with: range)
            }
        }

        var body = range
        var listPrefix = ""
        let text = full.substring(with: range)
        if text.hasPrefix("•\t") {
            listPrefix = "- "
            body = NSRange(location: range.location + 2, length: range.length - 2)
        } else if let match = text.range(of: #"^\d+\.\t"#, options: .regularExpression) {
            let consumed = (String(text[match]) as NSString).length
            listPrefix = String(text[match]).replacingOccurrences(of: "\t", with: " ")
            body = NSRange(location: range.location + consumed, length: range.length - consumed)
        }
        return listPrefix + inlineMarkdown(attributed, range: body)
    }

    /// Uses `enumerateAttributes` (every attribute, not just `.font`) since
    /// italic is tracked via `.obliqueness` — a separate attribute key from
    /// the font itself — so a run boundary can exist there even when the
    /// font on either side is identical.
    private static func inlineMarkdown(_ attributed: NSAttributedString, range: NSRange) -> String {
        guard range.length > 0 else { return "" }
        var result = ""
        attributed.enumerateAttributes(in: range, options: []) { attrs, subrange, _ in
            let runText = (attributed.string as NSString).substring(with: subrange)
            let font = attrs[.font] as? NSFont
            let obliqueness = (attrs[.obliqueness] as? Double) ?? (attrs[.obliqueness] as? NSNumber)?.doubleValue ?? 0
            if let font, font.fontName.contains("Mono") {
                result += "`\(runText)`"
            } else if let font, isBold(font) {
                result += "**\(runText)**"
            } else if obliqueness != 0 {
                result += "_\(runText)_"
            } else {
                result += runText
            }
        }
        return result
    }
}

/// The Transforms editor's text box, growing with its content the same way
/// `SelectableText`'s `AutoHeightTextView` does. Markdown mode edits the
/// plain `text` binding directly — literal syntax, literal editing.
/// Rich Text mode edits a real attributed representation with no Markdown
/// syntax in it at all, and re-serializes to Markdown (via
/// `MarkdownRichConversion`) into the same `text` binding after every
/// edit, so both modes always save the same thing without ever sharing a
/// live text buffer.
private struct MarkdownStyledEditor: NSViewRepresentable {
    @Binding var text: String
    let baseFont: NSFont
    let textColor: NSColor
    var isEditable: Bool
    var richStyling: Bool
    let commandBus: MarkdownEditorCommandBus

    func makeNSView(context: Context) -> AutoHeightTextView {
        let textView = AutoHeightTextView()
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.isRichText = true
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.font = baseFont
        textView.textColor = textColor
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.delegate = context.coordinator
        if richStyling {
            textView.textStorage?.setAttributedString(MarkdownRichConversion.attributed(from: text, baseFont: baseFont, textColor: textColor))
        } else {
            textView.string = text
        }
        textView.invalidateIntrinsicContentSize()
        bindCommandBus(to: textView, coordinator: context.coordinator)
        return textView
    }

    func updateNSView(_ textView: AutoHeightTextView, context: Context) {
        // Deliberately does NOT compare `textView.string` to `text` and
        // reload on mismatch — in Rich Text mode those two are never equal
        // (one is stripped-of-syntax attributed content, the other is the
        // serialized Markdown), so that comparison doesn't mean what it
        // used to. Each mode gets a fresh `MarkdownStyledEditor` instance
        // (a new one is created, not updated, whenever `mode` itself
        // switches — different branch of the `switch` in `MarkdownEditor`),
        // which already re-reads the current `text` in `makeNSView`; there
        // is no case where this same mounted instance needs to reload a
        // value it didn't just write itself.
        textView.isEditable = isEditable
        context.coordinator.baseFont = baseFont
        context.coordinator.textColor = textColor
        context.coordinator.richStyling = richStyling
        bindCommandBus(to: textView, coordinator: context.coordinator)
    }

    private func bindCommandBus(to textView: AutoHeightTextView, coordinator: Coordinator) {
        commandBus.handler = { [weak textView, weak coordinator] command in
            guard let textView, let coordinator else { return }
            coordinator.apply(command, to: textView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, baseFont: baseFont, textColor: textColor, richStyling: richStyling)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var baseFont: NSFont
        var textColor: NSColor
        var richStyling: Bool

        init(text: Binding<String>, baseFont: NSFont, textColor: NSColor, richStyling: Bool) {
            self.text = text
            self.baseFont = baseFont
            self.textColor = textColor
            self.richStyling = richStyling
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            sync(from: textView)
        }

        private func sync(from textView: NSTextView) {
            text.wrappedValue = richStyling
                ? MarkdownRichConversion.markdown(from: textView.attributedString(), baseFont: baseFont)
                : textView.string
            (textView as? AutoHeightTextView)?.invalidateIntrinsicContentSize()
        }

        func apply(_ command: MarkdownFormatCommand, to textView: NSTextView) {
            if richStyling {
                applyRich(command, to: textView)
            } else {
                applyMarkdownSyntax(command, to: textView)
            }
            sync(from: textView)
        }

        // MARK: - Markdown mode: literal syntax, toggled on repeat clicks

        private func applyMarkdownSyntax(_ command: MarkdownFormatCommand, to textView: NSTextView) {
            switch command {
            case .heading(let level):
                let prefix = String(repeating: "#", count: level) + " "
                toggleLinePrefix(textView.selectedRange(), in: textView, prefix: prefix, conflicting: ["### ", "## ", "# "])
            case .bold: toggleWrap(textView.selectedRange(), in: textView, marker: "**")
            case .italic: toggleWrap(textView.selectedRange(), in: textView, marker: "_")
            case .code: toggleWrap(textView.selectedRange(), in: textView, marker: "`")
            case .bulletList: toggleLinePrefix(textView.selectedRange(), in: textView, prefix: "- ", conflicting: ["- "])
            case .numberedList:
                var number = 1
                prefixLines(textView.selectedRange(), in: textView) { _ in defer { number += 1 }; return "\(number). " }
            }
        }

        /// Wraps the selection in `marker` on both sides — unless it's
        /// already wrapped in exactly that marker, in which case it
        /// unwraps instead. Without this, clicking Bold twice produced
        /// `****text****` rather than plain `text`.
        private func toggleWrap(_ range: NSRange, in textView: NSTextView, marker: String) {
            let full = textView.string as NSString
            let selected = full.substring(with: range)
            if selected.hasPrefix(marker), selected.hasSuffix(marker), selected.count >= marker.count * 2 {
                let inner = String(selected.dropFirst(marker.count).dropLast(marker.count))
                guard textView.shouldChangeText(in: range, replacementString: inner) else { return }
                textView.textStorage?.replaceCharacters(in: range, with: inner)
                textView.didChangeText()
                textView.setSelectedRange(NSRange(location: range.location, length: (inner as NSString).length))
            } else {
                wrap(range, in: textView, marker: marker)
            }
        }

        private func wrap(_ range: NSRange, in textView: NSTextView, marker: String) {
            let full = textView.string as NSString
            let selected = full.substring(with: range)
            let replacement = "\(marker)\(selected)\(marker)"
            guard textView.shouldChangeText(in: range, replacementString: replacement) else { return }
            textView.textStorage?.replaceCharacters(in: range, with: replacement)
            textView.didChangeText()
            textView.setSelectedRange(NSRange(location: range.location + marker.count, length: selected.count))
        }

        /// Replaces whichever of `conflicting` prefix this line already
        /// has (if any) with `prefix` — or, if it already has exactly
        /// `prefix`, strips it instead (toggle off). Without this,
        /// clicking H1 then H2 then H3 stacked all three ("### ## # ...")
        /// instead of switching heading level.
        private func toggleLinePrefix(_ range: NSRange, in textView: NSTextView, prefix: String, conflicting: [String]) {
            let full = textView.string as NSString
            let lineRange = full.lineRange(for: range)
            var line = full.substring(with: lineRange)
            for candidate in conflicting.sorted(by: { $0.count > $1.count }) where line.hasPrefix(candidate) {
                let wasExact = candidate == prefix
                line = String(line.dropFirst(candidate.count))
                replaceLine(lineRange, in: textView, with: wasExact ? line : prefix + line)
                return
            }
            replaceLine(lineRange, in: textView, with: prefix + line)
        }

        private func replaceLine(_ lineRange: NSRange, in textView: NSTextView, with newLine: String) {
            guard textView.shouldChangeText(in: lineRange, replacementString: newLine) else { return }
            textView.textStorage?.replaceCharacters(in: lineRange, with: newLine)
            textView.didChangeText()
            textView.setSelectedRange(NSRange(location: lineRange.location, length: (newLine as NSString).length))
        }

        private func prefixLines(_ range: NSRange, in textView: NSTextView, markerFor: (Int) -> String) {
            let full = textView.string as NSString
            let lineRange = full.lineRange(for: range)
            let block = full.substring(with: lineRange)
            let lines = block.components(separatedBy: "\n")
            let prefixed = lines.enumerated().map { index, line -> String in
                (index == lines.count - 1 && line.isEmpty) ? line : "\(markerFor(index))\(line)"
            }.joined(separator: "\n")
            guard textView.shouldChangeText(in: lineRange, replacementString: prefixed) else { return }
            textView.textStorage?.replaceCharacters(in: lineRange, with: prefixed)
            textView.didChangeText()
            textView.setSelectedRange(NSRange(location: lineRange.location, length: (prefixed as NSString).length))
        }

        // MARK: - Rich Text mode: real attributes, no Markdown characters

        private func applyRich(_ command: MarkdownFormatCommand, to textView: NSTextView) {
            switch command {
            case .heading(let level): toggleHeading(level, in: textView)
            case .bold: toggleBold(in: textView)
            case .italic: toggleItalic(in: textView)
            case .code: toggleCode(in: textView)
            case .bulletList: toggleListMarker(numbered: false, in: textView)
            case .numberedList: toggleListMarker(numbered: true, in: textView)
            }
        }

        /// Swaps to/from `Geist-SemiBold` by name (see
        /// `MarkdownRichConversion.boldVariant`) — no font-trait synthesis
        /// involved, just a genuinely different bundled font file.
        private func toggleBold(in textView: NSTextView) {
            let range = textView.selectedRange()
            guard range.length > 0, let storage = textView.textStorage else { return }
            var allBold = true
            storage.enumerateAttribute(.font, in: range, options: []) { value, _, stop in
                guard let font = value as? NSFont, MarkdownRichConversion.isBold(font) else {
                    allBold = false; stop.pointee = true; return
                }
            }
            storage.beginEditing()
            storage.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
                let font = (value as? NSFont) ?? self.baseFont
                let newFont = allBold ? MarkdownRichConversion.regularVariant(of: font) : MarkdownRichConversion.boldVariant(of: font)
                storage.addAttribute(.font, value: newFont, range: subrange)
            }
            storage.endEditing()
        }

        /// Toggles `.obliqueness` — see `MarkdownRichConversion`'s comment
        /// on why italic can't go through a font swap the way Bold does.
        private func toggleItalic(in textView: NSTextView) {
            let range = textView.selectedRange()
            guard range.length > 0, let storage = textView.textStorage else { return }
            let currentlyItalic = ((storage.attribute(.obliqueness, at: range.location, effectiveRange: nil) as? Double) ?? 0) != 0
            storage.beginEditing()
            if currentlyItalic {
                storage.removeAttribute(.obliqueness, range: range)
            } else {
                storage.addAttribute(.obliqueness, value: MarkdownRichConversion.italicObliqueness, range: range)
            }
            storage.endEditing()
        }

        private func toggleCode(in textView: NSTextView) {
            let range = textView.selectedRange()
            guard range.length > 0, let storage = textView.textStorage else { return }
            let mono = MarkdownRichConversion.codeFont(basedOn: baseFont)
            var allCode = true
            storage.enumerateAttribute(.font, in: range, options: []) { value, _, stop in
                guard let font = value as? NSFont, font.fontName == mono.fontName else { allCode = false; stop.pointee = true; return }
            }
            storage.beginEditing()
            storage.addAttribute(.font, value: allCode ? baseFont : mono, range: range)
            if allCode { storage.removeAttribute(.backgroundColor, range: range) }
            else { storage.addAttribute(.backgroundColor, value: textColor.withAlphaComponent(0.08), range: range) }
            storage.endEditing()
        }

        private func toggleHeading(_ level: Int, in textView: NSTextView) {
            guard let storage = textView.textStorage else { return }
            let full = storage.string as NSString
            let lineRange = full.lineRange(for: textView.selectedRange())
            guard lineRange.length > 0 else { return }
            let target = MarkdownRichConversion.headingFont(level: level, baseFont: baseFont)
            var alreadyThisLevel = false
            if let firstFont = storage.attribute(.font, at: lineRange.location, effectiveRange: nil) as? NSFont {
                alreadyThisLevel = abs(firstFont.pointSize - target.pointSize) < 0.01
            }
            storage.beginEditing()
            storage.addAttribute(.font, value: alreadyThisLevel ? baseFont : target, range: lineRange)
            storage.endEditing()
        }

        private func toggleListMarker(numbered: Bool, in textView: NSTextView) {
            guard let storage = textView.textStorage else { return }
            let full = storage.string as NSString
            let lineRange = full.lineRange(for: textView.selectedRange())
            let block = full.substring(with: lineRange)
            let lines = block.components(separatedBy: "\n")
            storage.beginEditing()
            var cursor = lineRange.location
            var number = 1
            for (index, line) in lines.enumerated() {
                defer { if numbered { number += 1 } }
                if index == lines.count - 1 && line.isEmpty { continue }
                let hasBullet = line.hasPrefix("•\t")
                let numberedMatch = line.range(of: #"^\d+\.\t"#, options: .regularExpression)
                if hasBullet || numberedMatch != nil {
                    let markerLength = hasBullet ? 2 : (numberedMatch.map { (String(line[$0]) as NSString).length } ?? 0)
                    storage.deleteCharacters(in: NSRange(location: cursor, length: markerLength))
                    let newLineLength = (line as NSString).length - markerLength
                    // Removing the marker also removes the hanging indent —
                    // otherwise the now-plain paragraph stays indented.
                    storage.addAttribute(.paragraphStyle, value: NSParagraphStyle(), range: NSRange(location: cursor, length: newLineLength))
                    cursor += newLineLength + 1
                } else {
                    let marker = numbered ? "\(number).\t" : "•\t"
                    let insertion = NSAttributedString(string: marker, attributes: [.font: baseFont, .foregroundColor: textColor])
                    storage.insert(insertion, at: cursor)
                    let newLineLength = (marker as NSString).length + (line as NSString).length
                    let style = NSMutableParagraphStyle()
                    style.firstLineHeadIndent = 0
                    style.headIndent = MarkdownRichConversion.listIndent
                    style.tabStops = [NSTextTab(textAlignment: .left, location: MarkdownRichConversion.listIndent)]
                    storage.addAttribute(.paragraphStyle, value: style, range: NSRange(location: cursor, length: newLineLength))
                    cursor += newLineLength + 1
                }
            }
            storage.endEditing()
        }
    }
}

/// A Markdown editor modeled on AssistantOS's own document toolbar (per
/// direct reference), slimmed down to H1-H3, Bold/Italic, inline Code, and
/// bulleted/numbered lists, plus a Rich Text/Markdown toggle. What's
/// actually saved (`text`) is always plain Markdown either way — Markdown
/// mode edits it directly; Rich Text mode edits a real attributed
/// rendering with no syntax characters in it and serializes back to
/// Markdown on every change (see `MarkdownRichConversion`).
struct MarkdownEditor: View {
    @Binding var text: String
    let font: NSFont
    let textColor: NSColor
    let theme: WindowTheme
    var isEditable: Bool = true

    @State private var mode: Mode = .richText
    @State private var commandBus = MarkdownEditorCommandBus()

    /// Plain `Geist-Regular` for Rich Text (should read like prose); the
    /// Markdown side always uses its own monospace font instead, regardless
    /// of what's passed in here, per direct request ("I'd like the markdown
    /// view to look more like code, mono type, etc.").
    private var richTextFont: NSFont { font }
    private let sourceFont = NSFont(name: "GeistMono-Regular", size: 13) ?? .monospacedSystemFont(ofSize: 13, weight: .regular)

    private enum Mode: String, CaseIterable, Identifiable {
        case richText = "Rich Text"
        case markdown = "Markdown"
        var id: String { rawValue }
    }

    /// Markdown mode reads more like a code box; Rich Text reads like a
    /// plain page. One container either way: a single background/border
    /// wrapping the toolbar, a hairline, then the content.
    private var containerBackground: Color { mode == .markdown ? theme.bg : theme.trough }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbarRow
                .padding(.horizontal, 10)
                .padding(.vertical, 8)

            Rectangle().fill(theme.hairline).frame(height: 1)

            editor
                .padding(16)
                // Established by `SelectableText`'s own use of this same
                // auto-height `NSViewRepresentable` recipe — without this,
                // the view has no reliable height to report on its first
                // layout pass and can render as a near-zero-height sliver,
                // which is what made the text area impossible to click into.
                .fixedSize(horizontal: false, vertical: true)
        }
        .background(containerBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(theme.hairline))
        // Mode switches recreate the editor instance below (a fresh
        // `MarkdownStyledEditor`, not an update to the old one) so it
        // always re-reads `text` fresh — the two modes never share a live
        // text buffer, only the saved `text` value between mountings.
        .id(mode)
    }

    @ViewBuilder
    private var editor: some View {
        switch mode {
        case .markdown:
            MarkdownStyledEditor(
                text: $text, baseFont: sourceFont, textColor: textColor,
                isEditable: isEditable, richStyling: false, commandBus: commandBus
            )
        case .richText:
            MarkdownStyledEditor(
                text: $text, baseFont: richTextFont, textColor: textColor,
                isEditable: isEditable, richStyling: true, commandBus: commandBus
            )
        }
    }

    /// A plain flat `HStack`, no scrolling — the slimmer control set fits
    /// the Transforms page's width outright.
    private var toolbarRow: some View {
        HStack(spacing: 10) {
            modeToggle
            if isEditable {
                separator
                textButton("H1", tooltip: "Heading 1") { commandBus.send(.heading(1)) }
                textButton("H2", tooltip: "Heading 2") { commandBus.send(.heading(2)) }
                textButton("H3", tooltip: "Heading 3") { commandBus.send(.heading(3)) }
                separator
                textButton("B", bold: true, tooltip: "Bold") { commandBus.send(.bold) }
                textButton("I", italic: true, tooltip: "Italic") { commandBus.send(.italic) }
                textButton("</>", mono: true, tooltip: "Code") { commandBus.send(.code) }
                separator
                iconButton(CentralIcons.listBullet, tooltip: "Bulleted list") { commandBus.send(.bulletList) }
                iconButton(CentralIcons.listNumbered, tooltip: "Numbered list") { commandBus.send(.numberedList) }
            }
        }
    }

    private var separator: some View {
        Rectangle().fill(theme.hairline).frame(width: 1, height: 16)
    }

    private var modeToggle: some View {
        HStack(spacing: 2) {
            ForEach(Mode.allCases) { candidate in
                Button {
                    mode = candidate
                } label: {
                    Text(candidate.rawValue)
                        .font(.custom("Geist-Medium", size: 11.5))
                        .foregroundColor(mode == candidate ? theme.text : theme.textFaint)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(mode == candidate ? theme.bg : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(theme.sel, in: RoundedRectangle(cornerRadius: 8))
    }

    private func textButton(_ label: String, bold: Bool = false, italic: Bool = false, mono: Bool = false, tooltip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.custom(mono ? "GeistMono-Regular" : (bold ? "Geist-SemiBold" : "Geist-Medium"), size: 12))
                .italic(italic)
                .lineLimit(1)
                .fixedSize()
                .frame(minWidth: 20, minHeight: 20)
                .padding(.horizontal, 2)
        }
        .buttonStyle(HarpsCardActionButtonStyle(theme: theme))
        .help(tooltip)
    }

    private func iconButton(_ svg: String, tooltip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            CentralIconView(svg: svg, color: theme.textFaint)
                .frame(width: 13, height: 13)
                .frame(minWidth: 20, minHeight: 20)
        }
        .buttonStyle(HarpsCardActionButtonStyle(theme: theme))
        .help(tooltip)
    }
}
