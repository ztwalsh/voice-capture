import SwiftUI

/// design.md §3's type table, verbatim — one shared definition rather than
/// each view picking its own size/weight/tracking, which is how the first
/// pass drifted from the spec (system fonts, approximate sizes, no
/// tracking at all). Geist/Geist Mono are registered by `FontLoader` at
/// launch from `Fonts/*.ttf`, extracted as static weight instances from the
/// variable fonts the prototype used — see that file's comment for why.
///
/// Each role bundles the font *and* the tracking design.md specifies for
/// it, since SwiftUI has no single modifier for both — call the role's
/// `tracking` alongside its `font` wherever it's used. Line-height isn't
/// directly settable per-Text either; SwiftUI's default leading is close
/// enough at these sizes that this doesn't attempt to force it.
enum HarpsType {
    struct Role {
        let font: Font
        let tracking: CGFloat
    }

    /// Overview stat values. 27/30, Semibold, −0.03em.
    static let display = Role(font: .custom("Geist-SemiBold", size: 27), tracking: -0.03 * 27)
    /// Window header. 17/22, Semibold, −0.02em.
    static let title = Role(font: .custom("Geist-SemiBold", size: 17), tracking: -0.02 * 17)
    /// Row headings. 15.5/20, Semibold, −0.012em.
    static let subtitle = Role(font: .custom("Geist-SemiBold", size: 15.5), tracking: -0.012 * 15.5)
    /// Transcript text. 13.5/21, Regular, 0.
    static let body = Role(font: .custom("Geist-Regular", size: 13.5), tracking: 0)
    /// Capsule status. 11/14, Medium, +0.01em.
    static let label = Role(font: .custom("Geist-Medium", size: 11), tracking: 0.01 * 11)
    /// Times, durations, paths. 10.5/14, Regular, mono, +0.01em.
    static let meta = Role(font: .custom("GeistMono-Regular", size: 10.5), tracking: 0.01 * 10.5)
    /// Sidebar and section headers. 9.5/12, Regular, mono, +0.09em, upper.
    static let section = Role(font: .custom("GeistMono-Regular", size: 9.5), tracking: 0.09 * 9.5)

    // A handful of sizes design.md's table doesn't name directly but the
    // window needs anyway — body text at a couple of secondary sizes and a
    // medium-weight sans for buttons/controls. Kept in the same family and
    // roughly the table's cadence rather than introducing new one-off sizes.
    static let bodySmall = Role(font: .custom("Geist-Regular", size: 12.5), tracking: 0)
    static let bodyMedium = Role(font: .custom("Geist-Medium", size: 12.5), tracking: 0)
    static let caption = Role(font: .custom("Geist-Regular", size: 11.5), tracking: 0)
    static let metaSmall = Role(font: .custom("GeistMono-Regular", size: 10), tracking: 0.01 * 10)
}

extension View {
    /// Applies both halves of a design.md type role — the font and its
    /// tracking — in one call.
    func harpsType(_ role: HarpsType.Role) -> some View {
        font(role.font).tracking(role.tracking)
    }
}
