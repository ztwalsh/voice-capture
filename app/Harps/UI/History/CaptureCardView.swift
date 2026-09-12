import SwiftUI

/// One capture, shown as a card. design.md §7: "cards carrying time,
/// destination app, duration and word count, body clamped to two lines,
/// expanding in place on click."
struct CaptureCardView: View {
    let capture: Capture
    let theme: WindowTheme
    var expanded: Bool = false
    var onToggleExpand: (() -> Void)?
    let onCopy: () -> Void
    let onDelete: () -> Void
    let onReveal: () -> Void

    @State private var isHovering = false
    /// motion.md's texts-reveal: staggered blurred rise on first appearance,
    /// applied per-row rather than to the list as a whole so each card
    /// settles independently.
    @State private var hasAppeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Text(capture.time)
                Text("·")
                Text(capture.appName)
                Text("·")
                Text("\(capture.durationSeconds)s")
                Text("·")
                Text("\(capture.wordCount)w")
                Spacer()
                // Actions stay reserved-but-invisible rather than
                // collapsing the row width on hover, which would shift
                // the metadata text sideways every time the mouse arrives.
                actions
                    .opacity(isHovering || expanded ? 1 : 0)
                    .animation(.easeOut(duration: 0.12), value: isHovering)
            }
            .harpsType(HarpsType.meta)
            .foregroundColor(theme.labelMono)

            Text(capture.text)
                .harpsType(HarpsType.body)
                .foregroundColor(theme.text)
                .lineLimit(expanded ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(isHovering ? theme.sel : theme.trough, in: RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .onTapGesture { onToggleExpand?() }
        .onHover { isHovering = $0 }
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

    private var actions: some View {
        HStack(spacing: 10) {
            Button(action: onCopy) {
                Image(systemName: "doc.on.doc")
            }
            .help("Copy")
            Button(action: onReveal) {
                Image(systemName: "folder")
            }
            .help("Reveal in Finder")
            Button(action: onDelete) {
                Image(systemName: "trash")
            }
            .help("Delete")
        }
        .buttonStyle(.plain)
        .foregroundColor(theme.textFaint)
    }
}
