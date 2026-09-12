import SwiftUI

enum HistoryLayout {
    static let headerHeight: CGFloat = 64
    /// The sidebar's own brand row is taller than the main header and
    /// bottom-aligned within it, specifically so the mark/wordmark clear
    /// the traffic-light buttons — confirmed still too tight at 64
    /// (matching the main header) on real hardware.
    static let sidebarHeaderHeight: CGFloat = 92
}

/// design.md §7's shape, refined to match `prototype/library-v2.html`: a
/// 236px sidebar and one header shared by every destination (title,
/// search, the Library/Document pill when relevant). The separate raw
/// `.md` panel design.md called for was dropped after building it —
/// Document view already shows the real file, emphasized for reading, and
/// having both was redundant rather than complementary.
struct HistoryRootView: View {
    @ObservedObject var model: HistoryViewModel
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var searchFocused: Bool

    var body: some View {
        let theme = WindowTheme(colorScheme)
        HStack(spacing: 0) {
            SidebarView(model: model, theme: theme)
                .frame(width: 236)
                .background(theme.side)

            Rectangle().fill(theme.hairline).frame(width: 1)

            VStack(spacing: 0) {
                WindowHeaderView(model: model, theme: theme, searchFocused: $searchFocused)
                content(theme: theme)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.bg)
        }
        .background(theme.bg)
        .frame(minWidth: 760, minHeight: 480)
        // The titlebar/traffic-light area contributes an automatic top
        // safe-area inset to hosted SwiftUI content in a `.fullSizeContentView`
        // window — it was landing differently on the sidebar's own top
        // padding versus the header's, throwing them out of alignment with
        // each other despite identical explicit padding values. Ignoring it
        // here means every bit of top spacing in this window is the padding
        // this file actually specifies, nothing implicit.
        .ignoresSafeArea(.container, edges: .top)
        .background(KeyEquivalentCatcher(key: "f", modifiers: .command) { searchFocused = true })
    }

    @ViewBuilder
    private func content(theme: WindowTheme) -> some View {
        if model.showingFeedback {
            FeedbackView(theme: theme)
        } else {
            switch model.destination {
            case .overview:
                OverviewView(model: model, theme: theme)
            case .transcripts:
                TranscriptsView(model: model, theme: theme)
            case .settings:
                SettingsView(model: model, theme: theme)
            }
        }
    }
}

/// One header for every destination, per `library-v2.html`'s `.head`: a
/// title, a search field (hidden on Settings, where it means nothing), and
/// the Library/Document pill (Transcripts only).
private struct WindowHeaderView: View {
    @ObservedObject var model: HistoryViewModel
    let theme: WindowTheme
    var searchFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 14) {
            Text(title)
                .harpsType(HarpsType.title)
                .foregroundColor(theme.text)

            Spacer()

            if model.destination != .settings && !model.showingFeedback {
                searchField
            }

            if model.destination == .transcripts {
                TranscriptsPillTabs(model: model, theme: theme)
            }
        }
        .padding(.horizontal, 22)
        .frame(height: HistoryLayout.headerHeight)
        .overlay(Rectangle().frame(height: 1).foregroundColor(theme.hairline), alignment: .bottom)
    }

    private var title: String {
        if model.showingFeedback { return "Feedback" }
        switch model.destination {
        case .overview: return "Overview"
        case .settings: return "Settings"
        case .transcripts:
            guard let day = model.selectedDay else { return "Transcripts" }
            return RelativeDay.label(for: day)
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            CentralIconView(svg: CentralIcons.search, color: theme.textFaint)
                .frame(width: 13, height: 13)
            TextField("Search transcripts", text: $model.searchText)
                .textFieldStyle(.plain)
                .focused(searchFocused)
        }
        .harpsType(HarpsType.bodySmall)
        .padding(.horizontal, 11)
        .frame(width: 210, height: 30)
        .background(theme.trough, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(theme.hairline))
    }

}

/// `library-v2.html`'s sliding pill tab, moved into the shared header.
private struct TranscriptsPillTabs: View {
    @ObservedObject var model: HistoryViewModel
    let theme: WindowTheme
    @Namespace private var pillNamespace

    var body: some View {
        HStack(spacing: 2) {
            ForEach(TranscriptsLayout.allCases) { layout in
                let selected = model.transcriptsLayout == layout
                Button {
                    withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.25)) {
                        model.transcriptsLayout = layout
                    }
                } label: {
                    Text(layout.rawValue)
                        .font(.custom(selected ? "Geist-Medium" : "Geist-Regular", size: 12.5))
                        .foregroundColor(selected ? theme.text : theme.textMuted)
                        .padding(.horizontal, 13)
                        .frame(height: 26)
                        .background {
                            if selected {
                                Capsule().fill(theme.bg)
                                    .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                                    .matchedGeometryEffect(id: "pill", in: pillNamespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(theme.trough, in: Capsule())
    }
}

/// design.md §7: mark+wordmark, three destinations, then a `RECENT` day
/// list with ⌘1–⌘9 shortcuts, then a hairline footer with the current file
/// path and a settings gear. Sized and spaced to match
/// `prototype/library-v2.html`'s `.side`/`.brand`/`.nav`/`.day` rules.
private struct SidebarView: View {
    @ObservedObject var model: HistoryViewModel
    let theme: WindowTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            VStack(alignment: .leading, spacing: 2) {
                destinationRow(.overview, icon: .overview)
                destinationRow(.transcripts, icon: .transcripts)
                destinationRow(.settings, icon: .settings)
            }
            .padding(.horizontal, 10)
            .padding(.top, 26)

            Text("RECENT")
                .harpsType(HarpsType.section)
                .foregroundColor(theme.textFaint)
                .padding(.horizontal, 21)
                .padding(.top, 22)
                .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(model.days.prefix(9).enumerated()), id: \.element) { index, day in
                        dayRow(day: day, shortcutIndex: index + 1)
                    }
                }
                .padding(.horizontal, 10)
                .background(ScrollbarHider())
            }

            Spacer(minLength: 0)
            footer
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            CaretMark()
                .frame(width: 15, height: 15)
                .padding(7.5)
                .background(theme.text, in: RoundedRectangle(cornerRadius: 9))
                .foregroundColor(theme.bg)
            Text("Harps")
                .font(.custom("Geist-SemiBold", size: 17))
                .tracking(-0.02 * 17)
                .foregroundColor(theme.text)
            Spacer()
        }
        .padding(.horizontal, 20)
        // Bottom-aligned in its own taller zone — confirmed still
        // overlapping the traffic lights at the main header's 64px height,
        // even bottom-aligned, on real hardware. `sidebarHeaderHeight`
        // gives it real clearance instead of guessing at another value.
        .frame(height: HistoryLayout.sidebarHeaderHeight, alignment: .bottom)
    }

    private func destinationRow(_ destination: Destination, icon: SidebarIcon.Kind) -> some View {
        let selected = !model.showingFeedback && model.destination == destination
        return Button {
            withAnimation(.easeOut(duration: 0.15)) {
                model.destination = destination
                model.showingFeedback = false
            }
        } label: {
            HStack(spacing: 11) {
                SidebarIcon(kind: icon, color: theme.text)
                    .frame(width: 16, height: 16)
                    .opacity(selected ? 1 : 0.62)
                Text(destination.rawValue)
                    .font(.custom(selected ? "Geist-Medium" : "Geist-Regular", size: 14))
                Spacer()
            }
            .foregroundColor(selected ? theme.text : theme.textMuted)
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(selected ? theme.sel : Color.clear, in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }

    private func dayRow(day: Date, shortcutIndex: Int) -> some View {
        let selected = model.destination == .transcripts && model.selectedDay == day
            && model.searchText.trimmingCharacters(in: .whitespaces).isEmpty
        return Button {
            model.selectDay(day)
        } label: {
            HStack(spacing: 9) {
                Text("→").foregroundColor(theme.textFaint).font(.system(size: 11))
                Text(RelativeDay.label(for: day))
                    .font(.system(size: 13.5))
                    .lineLimit(1)
                Spacer()
                if shortcutIndex <= 9 {
                    Text("⌘\(shortcutIndex)")
                        .font(.custom("GeistMono-Regular", size: 10.5))
                        .foregroundColor(theme.textFaint)
                }
            }
            .foregroundColor(selected ? theme.text : theme.textMuted)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(selected ? theme.sel : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(KeyEquivalent(Character("\(shortcutIndex)")), modifiers: .command)
    }

    /// A permanent bottom-of-sidebar row, styled exactly like the three
    /// destination rows above, per direct request — replacing what used to
    /// be the current file path plus a Settings shortcut (Settings already
    /// has its own row up top, so that shortcut was pure redundancy).
    private var footer: some View {
        let selected = model.showingFeedback
        return Button {
            withAnimation(.easeOut(duration: 0.15)) {
                model.showingFeedback = true
            }
        } label: {
            HStack(spacing: 11) {
                CentralIconView(svg: CentralIcons.megaphone, color: theme.text)
                    .frame(width: 16, height: 16)
                    .opacity(selected ? 1 : 0.62)
                Text("Feedback")
                    .font(.custom(selected ? "Geist-Medium" : "Geist-Regular", size: 14))
                Spacer()
            }
            .foregroundColor(selected ? theme.text : theme.textMuted)
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(selected ? theme.sel : Color.clear, in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .overlay(Rectangle().frame(height: 1).foregroundColor(theme.hairline), alignment: .top)
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
