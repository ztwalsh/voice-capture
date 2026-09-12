import CoreText
import Foundation

/// design.md §3: "Geist and Geist Mono, self-hosted... Both are SIL Open
/// Font License, so the same files ship inside the app rather than falling
/// back to a system substitute." The prototype only had woff2 (web-only;
/// CoreText can't load it), so these are static-weight instances extracted
/// from the same variable fonts — `Fonts/Geist-Regular.ttf`,
/// `-Medium.ttf`, `-SemiBold.ttf`, and the `GeistMono-` equivalents.
///
/// Registered programmatically with `CTFontManagerRegisterFontsForURL`
/// rather than declaratively via `ATSApplicationFontsPath` in Info.plist —
/// that key depends on the fonts landing at a specific path inside the
/// bundle, which isn't guaranteed by XcodeGen's default resource handling.
/// Doing it in code sidesteps that entirely: it just needs the files to be
/// bundle resources at all, wherever Xcode actually puts them.
enum FontLoader {
    private static let filenames = [
        "Geist-Regular", "Geist-Medium", "Geist-SemiBold",
        "GeistMono-Regular", "GeistMono-Medium",
    ]

    static func registerBundledFonts() {
        for name in filenames {
            // Called from `main.swift`'s top level, before the app delegate
            // exists — too early for `AppLog`, which is `@MainActor` and
            // needs the run loop already spinning to be safely reachable
            // from synchronous, nonisolated top-level code. A plain
            // `FileHandle.standardError` write is the honest option here.
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                FileHandle.standardError.write(Data("Missing bundled font: \(name).ttf\n".utf8))
                continue
            }
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                let message = error?.takeRetainedValue().localizedDescription ?? "unknown error"
                // A font already registered (e.g. a second launch in the
                // same session during development) reports as an error
                // here too — harmless, so this only logs, never blocks.
                FileHandle.standardError.write(Data("Font \(name) registration: \(message)\n".utf8))
            }
        }
    }
}
