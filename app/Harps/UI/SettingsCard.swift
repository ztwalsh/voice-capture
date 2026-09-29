import SwiftUI

/// A bordered group container for a cluster of settings/transform rows —
/// the iOS "grouped list" treatment (Settings.app, and this app's own
/// cardio-tracking sibling's `SettingsCard`), but per direct feedback kept
/// to *just* a border: no fill different from the page's own background,
/// no drop shadow — the page background stays exactly what it always was.
/// A plain hairline rectangle is what draws the group.
struct SettingsCard<Content: View>: View {
    let theme: WindowTheme
    @ViewBuilder var content: Content

    var body: some View {
        _VariadicView.Tree(SettingsCardLayout(theme: theme)) { content }
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(theme.hairline, lineWidth: 1))
    }
}

private struct SettingsCardLayout: _VariadicView_UnaryViewRoot {
    let theme: WindowTheme

    @ViewBuilder
    func body(children: _VariadicView.Children) -> some View {
        let items = Array(children.enumerated())
        VStack(spacing: 0) {
            ForEach(items, id: \.element.id) { index, child in
                child
                if index < items.count - 1 {
                    Rectangle().fill(theme.hairline).frame(height: 1)
                }
            }
        }
    }
}

/// Uppercase mono group label sitting above a `SettingsCard` — the same
/// `HarpsType.section` role "RECENT ACTIVITY" already used, just also now
/// naming each settings group ("DICTATION", "STORAGE", "GENERAL"...).
struct SettingsSectionLabel: View {
    let text: String
    let theme: WindowTheme

    var body: some View {
        Text(text)
            .harpsType(HarpsType.section)
            .foregroundColor(theme.textFaint)
            .padding(.horizontal, 4)
    }
}
