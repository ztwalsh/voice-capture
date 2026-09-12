import SwiftUI

/// design.md §7: "Label, one-line explanation, and a control. Rows
/// separated by hairlines." Actual persistence for hotkey/model/insertion
/// strategy is Phase 5's job per PLAN.md — everything hardcoded today is
/// shown as an honest, informational value rather than a control that looks
/// interactive but does nothing.
struct SettingsView: View {
    @ObservedObject var model: HistoryViewModel
    let theme: WindowTheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Settings")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(theme.text)
                    .padding(.bottom, 20)

                row(label: "Hotkey", explanation: "Push-to-talk trigger, held anywhere in macOS.") {
                    Text("⌥ Right Option").font(.system(size: 12.5, design: .monospaced))
                }
                row(label: "Model", explanation: "The on-device engine used to transcribe.") {
                    Text("SpeechAnalyzer").font(.system(size: 12.5))
                }
                row(label: "Insertion strategy", explanation: "How text lands at your cursor.") {
                    Text("Paste").font(.system(size: 12.5))
                }
                row(label: "Transcript folder", explanation: "Where your dictated text is kept.") {
                    Button(model.transcriptsDirectory.path) {
                        NSWorkspace.shared.activateFileViewerSelecting([model.transcriptsDirectory])
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundColor(theme.textMuted)
                }

                statement("Runs on device. Nothing leaves this Mac.")
                statement("Off by default. Audio has no use after transcription.")
            }
            .padding(28)
        }
    }

    private func row<Control: View>(label: String, explanation: String, @ViewBuilder control: () -> Control) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.text)
                Text(explanation)
                    .font(.system(size: 11.5))
                    .foregroundColor(theme.textSubtle)
            }
            Spacer()
            control()
                .foregroundColor(theme.text)
        }
        .padding(.vertical, 14)
        .overlay(Rectangle().frame(height: 1).foregroundColor(theme.hairline), alignment: .bottom)
    }

    private func statement(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(theme.textMuted)
            .padding(.vertical, 10)
    }
}
