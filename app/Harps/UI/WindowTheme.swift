import SwiftUI

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
            bg = Color(red: 0x0c / 255, green: 0x0c / 255, blue: 0x0d / 255)
            side = Color(red: 0x09 / 255, green: 0x09 / 255, blue: 0x0a / 255)
            sel = Color(red: 0x1d / 255, green: 0x1d / 255, blue: 0x20 / 255)
            trough = Color(red: 0x15 / 255, green: 0x15 / 255, blue: 0x17 / 255)
            hairline = Color.white.opacity(0.075)
            text = Color(red: 0xfa / 255, green: 0xfa / 255, blue: 0xfa / 255)
            textMuted = Color.white.opacity(0.56)
            textSubtle = Color.white.opacity(0.44)
            textFaint = Color.white.opacity(0.30)
            labelMono = Color.white.opacity(0.48)
            up = Color(red: 0x4a / 255, green: 0xde / 255, blue: 0x80 / 255)
            live = Color(red: 0xff / 255, green: 0x63 / 255, blue: 0x69 / 255)
        } else {
            bg = Color.white
            side = Color(red: 0xfb / 255, green: 0xfb / 255, blue: 0xfc / 255)
            sel = Color(red: 0xec / 255, green: 0xec / 255, blue: 0xed / 255)
            trough = Color(red: 0xf4 / 255, green: 0xf4 / 255, blue: 0xf5 / 255)
            hairline = Color.black.opacity(0.075)
            text = Color(red: 0x0a / 255, green: 0x0a / 255, blue: 0x0a / 255)
            textMuted = Color(red: 0x6a / 255, green: 0x6a / 255, blue: 0x6c / 255)
            textSubtle = Color(red: 0x86 / 255, green: 0x86 / 255, blue: 0x8a / 255)
            textFaint = Color(red: 0xa8 / 255, green: 0xa8 / 255, blue: 0xac / 255)
            labelMono = Color(red: 0x6f / 255, green: 0x71 / 255, blue: 0x80 / 255)
            up = Color(red: 0x1e / 255, green: 0x9e / 255, blue: 0x63 / 255)
            live = Color(red: 0xe5 / 255, green: 0x48 / 255, blue: 0x4d / 255)
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
