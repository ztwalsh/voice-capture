import SwiftUI

/// design.md §7: a sliding pill tab over two layouts of the same data, a
/// search field that filters every day at once, and a `.md` panel that
/// slides in showing the real file behind whatever is on screen.
struct TranscriptsView: View {
    @ObservedObject var model: HistoryViewModel
    let theme: WindowTheme
    @FocusState private var searchFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                header
                switch model.transcriptsLayout {
                case .library:
                    libraryLayout
                case .document:
                    documentLayout
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if model.showMarkdownPanel, let url = model.selectedDayFileURL {
                Divider().overlay(theme.hairline)
                MarkdownPanelView(url: url, model: model, theme: theme)
                    .frame(width: 360)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.showMarkdownPanel)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Text("Transcripts")
                .harpsType(HarpsType.title)
                .foregroundColor(theme.text)

            pillTabs

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(theme.textFaint)
                TextField("Search", text: $model.searchText)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .frame(width: 200)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(theme.trough, in: RoundedRectangle(cornerRadius: 8))
            .background(KeyEquivalentCatcher(key: "f", modifiers: .command) { searchFocused = true })

            Button {
                model.showMarkdownPanel.toggle()
            } label: {
                Image(systemName: "doc.plaintext")
            }
            .buttonStyle(.plain)
            .foregroundColor(model.showMarkdownPanel ? theme.text : theme.textFaint)
            .help("Show the raw Markdown file")
        }
    }

    /// motion.md: "the pill tweens width and position together" — a single
    /// `matchedGeometryEffect`-driven background sliding between the two
    /// tab labels, rather than each tab drawing its own static highlight.
    @Namespace private var pillNamespace

    private var pillTabs: some View {
        HStack(spacing: 2) {
            ForEach(TranscriptsLayout.allCases) { layout in
                let selected = model.transcriptsLayout == layout
                Button {
                    withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.25)) {
                        model.transcriptsLayout = layout
                    }
                } label: {
                    Text(layout.rawValue)
                        .font(.custom(selected ? "Geist-Medium" : "Geist-Regular", size: 12))
                        .foregroundColor(selected ? theme.text : theme.textMuted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background {
                            if selected {
                                Capsule().fill(theme.sel)
                                    .matchedGeometryEffect(id: "pill", in: pillNamespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(theme.trough, in: Capsule())
    }

    private var libraryLayout: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                Color.clear.frame(width: 0, height: 0).background(ScrollbarHider())
                ForEach(groupedByDay) { group in
                    Text(Self.dayHeaderFormatter.string(from: group.day))
                        .harpsType(HarpsType.section)
                        .foregroundColor(theme.textFaint)
                        .padding(.top, 10)
                    ForEach(group.captures) { capture in
                        CaptureCardView(
                            capture: capture, theme: theme,
                            expanded: model.expandedCaptureID == capture.id,
                            onToggleExpand: {
                                model.expandedCaptureID = model.expandedCaptureID == capture.id ? nil : capture.id
                            },
                            onCopy: { model.copy(capture) },
                            onDelete: { model.delete(capture) },
                            onReveal: { model.reveal(capture) }
                        )
                    }
                }
                if model.filteredCaptures.isEmpty {
                    Text(model.searchText.isEmpty ? "Nothing dictated yet." : "No matches for \"\(model.searchText)\".")
                        .harpsType(HarpsType.bodySmall)
                        .foregroundColor(theme.textFaint)
                        .padding(.top, 20)
                }
            }
        }
    }

    private struct DayGroup: Identifiable {
        let day: Date
        let captures: [Capture]
        var id: Date { day }
    }

    private var groupedByDay: [DayGroup] {
        var order: [Date] = []
        var buckets: [Date: [Capture]] = [:]
        for capture in model.filteredCaptures {
            if buckets[capture.day] == nil { order.append(capture.day) }
            buckets[capture.day, default: []].append(capture)
        }
        return order.map { DayGroup(day: $0, captures: buckets[$0] ?? []) }
    }

    /// design.md §7: "Search filters every day at once ... in both
    /// layouts." While searching, only days with a matching capture stay in
    /// the picker — otherwise Document mode would silently ignore the
    /// search the way it did before this was wired in.
    private var searchableDays: [Date] {
        guard !model.searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return model.days }
        let matchingDays = Set(model.filteredCaptures.map { $0.day })
        return model.days.filter { matchingDays.contains($0) }
    }

    /// Falls back to the first day that still matches an active search when
    /// the currently-selected day has been filtered out, rather than
    /// leaving the reader looking at a day search says has no hits.
    private var displayedDayFileURL: URL? {
        if let selected = model.selectedDayFileURL,
           searchableDays.contains(where: { model.dayFileURL(for: $0) == selected }) {
            return selected
        }
        return searchableDays.first.flatMap { model.dayFileURL(for: $0) }
    }

    private var documentLayout: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(searchableDays, id: \.self) { day in
                    let url = model.dayFileURL(for: day)
                    Button {
                        model.selectedDayFileURL = url
                    } label: {
                        Text(Self.dayHeaderFormatter.string(from: day))
                            .harpsType(HarpsType.bodySmall)
                            .foregroundColor(model.selectedDayFileURL == url ? theme.text : theme.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(model.selectedDayFileURL == url ? theme.sel : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 150)

            Divider().overlay(theme.hairline)

            ScrollView {
                Color.clear.frame(width: 0, height: 0).background(ScrollbarHider())
                if let url = displayedDayFileURL, let content = model.rawContent(at: url) {
                    DocumentBodyView(content: content, theme: theme, highlight: model.searchText)
                        .frame(maxWidth: 700, alignment: .leading)
                        .padding(24)
                } else {
                    Text(model.searchText.isEmpty ? "No day selected." : "No matches for \"\(model.searchText)\".")
                        .foregroundColor(theme.textFaint)
                        .padding(24)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private static let dayHeaderFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()
}

/// design.md §7: "the whole day set in Geist Mono ... frontmatter shown as
/// frontmatter, and the `##` markers left visible but dimmed."
private struct DocumentBodyView: View {
    let content: String
    let theme: WindowTheme
    var highlight: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(content.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                Text(attributedLine(line))
                    .font(.custom("GeistMono-Regular", size: 12.5))
                    .foregroundColor(color(for: line))
                    .textSelection(.enabled)
            }
        }
    }

    /// design.md §7: "Matches highlight in a warm translucent mark." Case-
    /// insensitive, every occurrence per line.
    private func attributedLine(_ line: String) -> AttributedString {
        var attributed = AttributedString(line.isEmpty ? " " : line)
        let needle = highlight.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return attributed }

        var searchRange = attributed.startIndex..<attributed.endIndex
        while let range = attributed[searchRange].range(of: needle, options: .caseInsensitive) {
            attributed[range].backgroundColor = Color.yellow.opacity(0.35)
            searchRange = range.upperBound..<attributed.endIndex
        }
        return attributed
    }

    private func color(for line: String) -> Color {
        if line == "---" || line.hasPrefix("date:") || line.hasPrefix("captures:") || line.hasPrefix("words:") {
            return theme.textFaint
        }
        if line.hasPrefix("## ") { return theme.textFaint }
        return theme.text
    }
}

private struct MarkdownPanelView: View {
    let url: URL
    @ObservedObject var model: HistoryViewModel
    let theme: WindowTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(url.lastPathComponent)
                    .harpsType(HarpsType.bodyMedium)
                if let bytes = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int {
                    Text(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))
                        .harpsType(HarpsType.meta)
                        .foregroundColor(theme.textFaint)
                }
                Spacer()
            }
            .padding(12)
            .overlay(Rectangle().frame(height: 1).foregroundColor(theme.hairline), alignment: .bottom)

            ScrollView {
                Color.clear.frame(width: 0, height: 0).background(ScrollbarHider())
                if let content = model.rawContent(at: url) {
                    DocumentBodyView(content: content, theme: theme)
                        .padding(12)
                }
            }
        }
        .background(theme.side)
    }
}

/// ⌘F focuses search. SwiftUI has no direct "global menu command" hook in
/// this AppKit-hosted window without a full `Commands` scene, so this
/// attaches a hidden button carrying the keyboard shortcut instead.
private struct KeyEquivalentCatcher: NSViewRepresentable {
    let key: KeyEquivalent
    let modifiers: EventModifiers
    let action: () -> Void

    func makeNSView(context: Context) -> NSView {
        let host = NSHostingView(rootView: Button("", action: action)
            .keyboardShortcut(key, modifiers: modifiers)
            .opacity(0))
        host.frame = .zero
        return host
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
