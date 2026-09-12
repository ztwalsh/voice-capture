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
                actions
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
        .background(theme.trough, in: RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .onTapGesture { onToggleExpand?() }
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
