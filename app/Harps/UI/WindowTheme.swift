import AppKit
import SwiftUI

/// `.scrollIndicators(.hidden)` — the documented SwiftUI way to do this —
/// silently does not take effect anywhere in this app's history window,
/// confirmed live: the scrollbar stayed visible in every tab after applying
/// it and rebuilding. Same class of bug as the capsule's Reduce Motion
/// environment key not propagating: this app hosts SwiftUI through
/// `NSHostingView` inside plain `NSWindow`/`NSPanel` instances without a
/// `WindowGroup`/`App` scene, which is unusual enough that some of
/// SwiftUI's internal environment plumbing doesn't reach it. Going straight
/// to the underlying `NSScrollView` sidesteps whatever that gap is.
/// Applied as a zero-size `.background()` inside a `ScrollView`'s content
/// so `enclosingScrollView` resolves to the real scroller.
struct ScrollbarHider: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { Self.hide(from: view) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { Self.hide(from: nsView) }
    }

    private static func hide(from view: NSView) {
        guard let scrollView = view.enclosingScrollView else { return }
        // `.overlay` is macOS's own "only while scrolling" transient
        // scroller — keeping the scroller enabled but forcing this style is
        // what actually gives that behavior. The system apparently defaults
        // to `.legacy` (always visible) here, plausibly for the same
        // hosting-environment reason `.scrollIndicators(.hidden)` itself
        // didn't take effect.
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
    }
}

/// design.md §3's colour tokens for the window — the sidebar, cards, and the
/// `--up` accent none of which the capsule needs. Deliberately a separate
/// type from the capsule's own private `Theme` in `CapsuleView.swift` rather
/// than a shared one: the capsule is working, tested code, and duplicating
/// a small color table is cheaper than risking it while building the window.
struct WindowTheme {
    let isDark: Bool
    let bg: Color
    let side: Color
    let sel: Color
    let trough: Color
    let hairline: Color
    let text: Color
    let textMuted: Color
    let textSubtle: Color
    let textFaint: Color
    let labelMono: Color
    let up: Color
    let live: Color

    init(_ colorScheme: ColorScheme) {
        isDark = colorScheme == .dark
        if isDark {
            // Updated neutral scale (still §3, values now carry a deliberate
            // faint blue tint instead of pure grey — "a slightly blue feel").
            // neutral/950 turned out to be a dead end for `side`: it's
            // barely distinguishable from pure black (confirmed live —
            // "looks too black to me"), because 950 is the one step in this
            // four-step scale with almost no blue in it. `side` is instead
            // hand-extrapolated one step darker than neutral/900 along the
            // same blue lean (same +9 blue-vs-red delta 900 itself has)
            // rather than reusing 950, so the sidebar reads as clearly part
            // of the same bluish family as the content area, just darker.
            side = Color(red: 0x0a / 255, green: 0x0a / 255, blue: 0x13 / 255)
            bg = Color(red: 0x0d / 255, green: 0x0d / 255, blue: 0x16 / 255) // neutral/900
            trough = Color(red: 0x13 / 255, green: 0x13 / 255, blue: 0x1c / 255) // neutral/850
            sel = Color(red: 0x1c / 255, green: 0x1c / 255, blue: 0x24 / 255) // neutral/800
            hairline = Color.white.opacity(0.075)
            text = Color(red: 0xfa / 255, green: 0xfa / 255, blue: 0xfa / 255) // neutral/50
            textMuted = Color.white.opacity(0.56)
            textSubtle = Color.white.opacity(0.44)
            textFaint = Color.white.opacity(0.30)
            labelMono = Color.white.opacity(0.48)
            up = Color(red: 0x4a / 255, green: 0xde / 255, blue: 0x80 / 255) // green/400
            live = Color(red: 0x13 / 255, green: 0x0c / 255, blue: 0xee / 255) // indigo/500
        } else {
            bg = Color(red: 0xfa / 255, green: 0xfa / 255, blue: 0xfa / 255) // neutral/50
            side = Color(red: 0xfb / 255, green: 0xfb / 255, blue: 0xfc / 255)
            sel = Color(red: 0xec / 255, green: 0xec / 255, blue: 0xed / 255)
            trough = Color(red: 0xf4 / 255, green: 0xf4 / 255, blue: 0xf5 / 255)
            hairline = Color.black.opacity(0.075)
            text = Color(red: 0x0a / 255, green: 0x0a / 255, blue: 0x0a / 255)
            textMuted = Color(red: 0x6a / 255, green: 0x6a / 255, blue: 0x6c / 255)
            textSubtle = Color(red: 0x86 / 255, green: 0x86 / 255, blue: 0x8a / 255)
            textFaint = Color(red: 0xa8 / 255, green: 0xa8 / 255, blue: 0xac / 255)
            labelMono = Color(red: 0x6f / 255, green: 0x71 / 255, blue: 0x80 / 255)
            up = Color(red: 0x4a / 255, green: 0xde / 255, blue: 0x80 / 255) // green/400, same both appearances
            live = Color(red: 0x13 / 255, green: 0x0c / 255, blue: 0xee / 255) // indigo/500, same both appearances
        }
    }
}

/// The caret mark from design.md §4 — an I-beam, since Harps puts text at a
/// caret. Used at 14px reversed out of a rounded tile, matching the
/// sidebar/popover spec.
struct CaretMark: View {
    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width / 16
            Path { path in
                path.move(to: CGPoint(x: 5.6 * s, y: 2.6 * s))
                path.addLine(to: CGPoint(x: 10.4 * s, y: 2.6 * s))
            }
            .stroke(style: StrokeStyle(lineWidth: 1.7 * s, lineCap: .round))
            Path { path in
                path.move(to: CGPoint(x: 5.6 * s, y: 13.4 * s))
                path.addLine(to: CGPoint(x: 10.4 * s, y: 13.4 * s))
            }
            .stroke(style: StrokeStyle(lineWidth: 1.7 * s, lineCap: .round))
            Path { path in
                path.move(to: CGPoint(x: 8 * s, y: 2.6 * s))
                path.addLine(to: CGPoint(x: 8 * s, y: 13.4 * s))
            }
            .stroke(style: StrokeStyle(lineWidth: 1.7 * s, lineCap: .round))
        }
    }
}

/// design.md's palette is deliberately monochrome outside of `--live` and
/// `--up` — "colour carries meaning, not chrome" is the whole point of §2's
/// principles. The system's default prominent-button blue has no home in
/// that language, so every primary action in this app uses a solid
/// `--text`-on-`--bg` fill instead — the same high-contrast tile treatment
/// already used for the caret mark itself.
struct HarpsPrimaryButtonStyle: ButtonStyle {
    let theme: WindowTheme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Geist-Medium", size: 12.5))
            .foregroundColor(theme.bg)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(theme.text.opacity(configuration.isPressed ? 0.85 : 1),
                        in: RoundedRectangle(cornerRadius: 8))
    }
}

/// The lower-emphasis counterpart — `--trough` fill with a hairline border,
/// the same treatment design.md's popover record button and window controls
/// use.
struct HarpsSecondaryButtonStyle: ButtonStyle {
    let theme: WindowTheme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Geist-Medium", size: 12))
            .foregroundColor(theme.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(configuration.isPressed ? theme.sel : theme.trough,
                        in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(theme.hairline))
    }
}

/// `library-v2.html`'s `.sw` switch: a 36x21 pill with a sliding thumb.
/// SwiftUI's default macOS `Toggle` renders as a checkbox unless styled —
/// this replaces that with the app's own dark-pill switch.
struct HarpsToggleStyle: ToggleStyle {
    let theme: WindowTheme
    func makeBody(configuration: Configuration) -> some View {
        Button {
            // Animating via `withAnimation` at the actual mutation, not a
            // passive `.animation(value:)` below — `configuration.isOn` is a
            // binding into an external `@Published` property
            // (`SettingsStore`), and a trailing `.animation(value:)` modifier
            // doesn't reliably pick up state changes that originate outside
            // the view it's attached to.
            withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.25)) {
                configuration.isOn.toggle()
            }
        } label: {
            RoundedRectangle(cornerRadius: 999)
                .fill(configuration.isOn ? theme.text : theme.sel)
                .frame(width: 36, height: 21)
                .overlay(
                    Circle()
                        .fill(theme.bg)
                        .shadow(color: .black.opacity(0.22), radius: 3, y: 1)
                        .frame(width: 17, height: 17)
                        .offset(x: configuration.isOn ? 7.5 : -7.5)
                )
        }
        .buttonStyle(.plain)
    }
}

/// The visual for a borderless-menu chip: flat trough background, hairline
/// border, one hand-drawn chevron. Pair with `.menuStyle(.borderlessButton)`
/// — the default `Menu` style wraps a label in its own native pull-down
/// bezel, which duplicates whatever background/border the label draws
/// itself, so this only ever gets used with the native chrome switched off.
/// Shared by Settings' Hotkey control and Transcripts' search filters.
struct HarpsMenuLabel: View {
    let text: String
    let theme: WindowTheme
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 4 : 5) {
            Text(text)
            CentralIconView(svg: CentralIcons.chevronDown, color: theme.text)
                .frame(width: compact ? 9 : 10, height: compact ? 9 : 10)
        }
        .font(.custom("Geist-Medium", size: compact ? 11 : 12))
        .foregroundColor(theme.text)
        .padding(.horizontal, compact ? 10 : 12)
        .padding(.vertical, compact ? 5 : 6)
        .background(theme.trough, in: RoundedRectangle(cornerRadius: compact ? 7 : 8))
        .overlay(RoundedRectangle(cornerRadius: compact ? 7 : 8).strokeBorder(theme.hairline))
    }
}

/// SwiftUI's `Menu` draws its own disclosure indicator no matter what —
/// confirmed live that `.menuStyle(.borderlessButton)` plus
/// `.menuIndicator(.hidden)` still leaves a native caret behind, sitting
/// next to `HarpsMenuLabel`'s own hand-drawn one and producing two visible
/// carets. This sidesteps `Menu` entirely: an `NSPopUpButton` with its
/// bezel switched off and made nearly transparent (`alphaValue`, not
/// `isHidden` — a hidden view stops receiving clicks, a near-zero-alpha one
/// doesn't) sits as an invisible tap target over a plain `HarpsMenuLabel`,
/// so the native menu still opens and updates state, but the only chevron
/// anyone ever sees is the one this file draws.
struct HarpsDropdown: View {
    let titles: [String]
    let selected: String
    let theme: WindowTheme
    var compact = false
    let onSelect: (String) -> Void

    var body: some View {
        HarpsMenuLabel(text: selected, theme: theme, compact: compact)
            .overlay(
                InvisiblePopUpButton(
                    titles: titles,
                    selectedIndex: titles.firstIndex(of: selected) ?? 0
                ) { index in
                    guard titles.indices.contains(index) else { return }
                    onSelect(titles[index])
                }
            )
    }
}

private struct InvisiblePopUpButton: NSViewRepresentable {
    let titles: [String]
    let selectedIndex: Int
    let onSelect: (Int) -> Void

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.isBordered = false
        // Alpha near zero, not `isHidden`/`alpha: 0` exactly — AppKit still
        // dispatches mouse events to a nearly-invisible view, but a fully
        // hidden or fully transparent one can stop compositing reliably
        // across macOS versions. This keeps it functionally invisible while
        // guaranteeing clicks land.
        button.alphaValue = 0.011
        button.target = context.coordinator
        button.action = #selector(Coordinator.selectionChanged(_:))
        return button
    }

    func updateNSView(_ nsView: NSPopUpButton, context: Context) {
        if nsView.itemTitles != titles {
            nsView.removeAllItems()
            nsView.addItems(withTitles: titles)
        }
        if nsView.indexOfSelectedItem != selectedIndex {
            nsView.selectItem(at: selectedIndex)
        }
        context.coordinator.onSelect = onSelect
    }

    func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect) }

    final class Coordinator: NSObject {
        var onSelect: (Int) -> Void
        init(onSelect: @escaping (Int) -> Void) { self.onSelect = onSelect }
        @objc func selectionChanged(_ sender: NSPopUpButton) {
            onSelect(sender.indexOfSelectedItem)
        }
    }
}

/// `library-v2.html`'s `.srow .v`: a mono value chip for an informational
/// settings row (hotkey, model, insertion strategy).
struct SettingsValueChip: View {
    let text: String
    let theme: WindowTheme
    var body: some View {
        Text(text)
            .font(.custom("GeistMono-Regular", size: 11.5))
            .foregroundColor(theme.textMuted)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(theme.trough, in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(theme.hairline))
    }
}

/// `library-v2.html`'s `.chip`: the small pill naming which app a capture
/// landed in, on a capture card.
struct AppTagChip: View {
    let text: String
    let theme: WindowTheme
    var hovering = false
    var body: some View {
        Text(text)
            .font(.system(size: 10.5))
            .foregroundColor(theme.textSubtle)
            .padding(.horizontal, 6)
            .padding(.vertical, 1.5)
            .background(hovering ? theme.sel : theme.trough, in: RoundedRectangle(cornerRadius: 5))
    }
}

/// The sidebar nav's three destination icons — now Central Icons (grid,
/// file-text, sliders) instead of hand-drawn line art, matching the rest of
/// the icon pass. Caller applies emphasis via `.opacity()`, same as the
/// `library-v2.html` reference's `.nav[aria-selected="true"] svg { opacity: 1 }`.
struct SidebarIcon: View {
    enum Kind { case overview, transcripts, settings }
    let kind: Kind
    let color: Color

    var body: some View {
        CentralIconView(svg: svg, color: color)
    }

    private var svg: String {
        switch kind {
        case .overview: return CentralIcons.grid
        case .transcripts: return CentralIcons.fileText
        case .settings: return CentralIcons.settingsSlider
        }
    }
}

/// A small icon button for a hover-revealed row action (copy/delete/reveal)
/// — shared by `CaptureCardView`'s row actions and `DocumentBodyView`'s
/// per-capture toolbar so both use the same look and the same tooltip
/// treatment (the label only ever surfaces as `.help(_:)` text on hover).
struct HarpsActionIcon: View {
    let svg: String
    let tooltip: String
    let theme: WindowTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CentralIconView(svg: svg, color: theme.textFaint)
                .frame(width: 13, height: 13)
        }
        .buttonStyle(HarpsCardActionButtonStyle(theme: theme))
        .help(tooltip)
    }
}

struct HarpsCardActionButtonStyle: ButtonStyle {
    let theme: WindowTheme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? theme.text : theme.textFaint)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(configuration.isPressed ? theme.sel : Color.clear, in: RoundedRectangle(cornerRadius: 5))
    }
}

/// design.md §7: "the whole day set in Geist Mono ... frontmatter shown as
/// frontmatter, and the `##` markers left visible but dimmed." Matches
/// `library-v2.html`'s `.entry-h`/`.entry-b`: the time/app/duration heading
/// is bold and full-brightness, the `##` marker and frontmatter are dim,
/// and the transcript body itself is muted — quieter than the heading, per
/// the mockup, not the loudest thing on the page.
///
/// Renders per-`Capture` rather than walking the raw file line by line, so
/// each entry can carry a selection-anchored toolbar (see
/// `CaptureDocumentBlock` below). Frontmatter is still pulled straight from
/// the raw file text above that, keeping design.md's "the file is the real
/// thing" intent for the one part that's pure metadata anyway.
struct DocumentBodyView: View {
    let content: String
    let captures: [Capture]
    let theme: WindowTheme
    var highlight: String = ""
    var onCopy: ((Capture, String) -> Void)?
    var onDelete: ((Capture) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(frontmatterLines.enumerated()), id: \.offset) { _, line in
                Text(line.isEmpty ? " " : line)
                    .font(.custom("GeistMono-Regular", size: 11.5))
                    .foregroundColor(theme.textFaint)
            }
            ForEach(Array(captures.enumerated()), id: \.element.id) { index, capture in
                CaptureDocumentBlock(
                    capture: capture, theme: theme, highlight: highlight,
                    isFirst: index == 0 && frontmatterLines.isEmpty,
                    onCopy: onCopy, onDelete: onDelete
                )
            }
        }
    }

    private var frontmatterLines: [String] {
        let lines = content.components(separatedBy: "\n")
        guard lines.first == "---",
              let closingIndex = lines.dropFirst().firstIndex(where: { $0 == "---" })
        else { return [] }
        return Array(lines[0...closingIndex])
    }
}

/// One capture's heading + body in Document view. The body is a
/// `SelectableText` (real `NSTextView` selection, not SwiftUI's opaque
/// `.textSelection`) specifically so this can track the selection's own
/// rect and float a little copy/delete bar just below it — replacing an
/// earlier per-row hover toolbar per direct request ("show up just below
/// what's highlighted", "icons ... so small").
private struct CaptureDocumentBlock: View {
    let capture: Capture
    let theme: WindowTheme
    let highlight: String
    let isFirst: Bool
    let onCopy: ((Capture, String) -> Void)?
    let onDelete: ((Capture) -> Void)?

    @State private var selectedRange = NSRange(location: 0, length: 0)
    @State private var selectionRect: CGRect?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            heading
                .padding(.top, isFirst ? 0 : 22)
                .padding(.bottom, 2)

            ZStack(alignment: .topLeading) {
                SelectableText(
                    text: capture.text,
                    font: .init(name: "GeistMono-Regular", size: 13.5) ?? .systemFont(ofSize: 13.5),
                    textColor: NSColor(theme.textMuted),
                    lineSpacing: 6,
                    highlight: highlight
                ) { range, rect in
                    selectedRange = range
                    selectionRect = rect
                }
                .fixedSize(horizontal: false, vertical: true)

                if let selectionRect, selectedRange.length > 0, onCopy != nil || onDelete != nil {
                    toolbar
                        .offset(x: max(selectionRect.minX, 0), y: selectionRect.maxY + 6)
                        .transition(.opacity.combined(with: .offset(y: -4)))
                }
            }
        }
        .animation(.easeOut(duration: 0.12), value: selectionRect != nil)
    }

    private var toolbar: some View {
        HStack(spacing: 3) {
            if let onCopy {
                toolbarButton(CentralIcons.copy, tooltip: "Copy") {
                    let text = capture.text as NSString
                    onCopy(capture, text.substring(with: selectedRange))
                }
            }
            if let onDelete {
                toolbarButton(CentralIcons.trash, tooltip: "Delete") { onDelete(capture) }
            }
        }
        .padding(5)
        .background(theme.bg, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(theme.hairline))
        .shadow(color: .black.opacity(0.16), radius: 8, y: 3)
    }

    private func toolbarButton(_ svg: String, tooltip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            CentralIconView(svg: svg, color: theme.text)
                .frame(width: 17, height: 17)
                .padding(5)
        }
        .buttonStyle(HarpsCardActionButtonStyle(theme: theme))
        .help(tooltip)
    }

    private var heading: some View {
        HStack(spacing: 10) {
            Text("##")
                .font(.custom("GeistMono-Regular", size: 14))
                .foregroundColor(theme.textFaint)
            Text("\(capture.time) · \(capture.appName) · \(capture.durationSeconds)s")
                .font(.custom("GeistMono-Medium", size: 14))
                .foregroundColor(theme.text)
        }
    }
}

/// "Today"/"Yesterday" then weekday names, matching `library-v2.html`'s
/// `DAYS[].label` — falls back to a full date once it's further back than a
/// weekday name can disambiguate.
enum RelativeDay {
    static func label(for day: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        let daysAgo = calendar.dateComponents([.day], from: calendar.startOfDay(for: day),
                                               to: calendar.startOfDay(for: Date())).day ?? 999
        if daysAgo < 7 {
            let f = DateFormatter()
            f.dateFormat = "EEEE"
            return f.string(from: day)
        }
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: day)
    }
}
