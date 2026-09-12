import SwiftUI

/// One capture, per `library-v2.html`'s `.card`: no outline or resting
/// background at all — just a hairline-free row that picks up `--trough`
/// on hover, a `--label-mono` timestamp, an app-name chip, faint
/// duration/word-count, and text actions that only appear on hover.
struct CaptureCardView: View {
    let capture: Capture
    let theme: WindowTheme
    var expanded: Bool = false
    var highlight: String = ""
    var onToggleExpand: (() -> Void)?
    let onCopy: () -> Void
    let onDelete: () -> Void
    let onReveal: () -> Void

    @State private var isHovering = false
    /// motion.md's texts-reveal: staggered blurred rise on first appearance,
    /// applied per-row rather than to the list as a whole.
    @State private var hasAppeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 10) {
                Text(capture.time)
                    .font(.custom("GeistMono-Regular", size: 10.5))
                    .foregroundColor(theme.labelMono)
                AppTagChip(text: capture.appName, theme: theme, hovering: isHovering)
                Text("\(capture.durationSeconds)s · \(capture.wordCount)w")
                    .font(.custom("GeistMono-Regular", size: 10.5))
                    .foregroundColor(theme.textFaint)
                Spacer()
                actions
                    .opacity(isHovering || expanded ? 1 : 0)
                    .animation(.easeOut(duration: 0.12), value: isHovering)
            }

            Text(attributedText)
                .font(.system(size: 13.5))
                .lineSpacing(4)
                .foregroundColor(theme.text)
                .lineLimit(expanded ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(isHovering ? theme.trough : Color.clear, in: RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .onTapGesture { onToggleExpand?() }
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.25), value: isHovering)
        .animation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.3), value: expanded)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 6)
        .blur(radius: hasAppeared ? 0 : 3)
        .onAppear {
            withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.4)) {
                hasAppeared = true
            }
        }
    }

    /// design.md §7: "Matches highlight in a warm translucent mark."
    private var attributedText: AttributedString {
        var attributed = AttributedString(capture.text)
        let needle = highlight.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return attributed }
        var searchRange = attributed.startIndex..<attributed.endIndex
        while let range = attributed[searchRange].range(of: needle, options: .caseInsensitive) {
            attributed[range].backgroundColor = Color.yellow.opacity(0.35)
            searchRange = range.upperBound..<attributed.endIndex
        }
        return attributed
    }

    private var actions: some View {
        HStack(spacing: 2) {
            HarpsActionIcon(svg: CentralIcons.copy, tooltip: "Copy", theme: theme, action: onCopy)
            HarpsActionIcon(svg: CentralIcons.finder, tooltip: "Show in Finder", theme: theme, action: onReveal)
            HarpsActionIcon(svg: CentralIcons.trash, tooltip: "Delete", theme: theme, action: onDelete)
        }
    }
}
