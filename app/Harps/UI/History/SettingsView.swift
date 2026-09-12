import SwiftUI

/// design.md §7: "Label, one-line explanation, and a control. Rows
/// separated by hairlines." Hotkey/model/insertion strategy have exactly
/// one implementation each, so they're shown as honest, informational
/// values — PLAN.md's real Phase 5 settings, launch-at-login and keep-audio,
/// are genuine controls backed by `SettingsStore`. This also carries the
/// permissions and recent-errors sections PLAN.md's onboarding and logging
/// requirements need a home for.
struct SettingsView: View {
    @ObservedObject var model: HistoryViewModel
    let theme: WindowTheme
    @ObservedObject private var settings = SettingsStore.shared
    @ObservedObject private var log = AppLog.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Settings")
                    .harpsType(HarpsType.title)
                    .foregroundColor(theme.text)
                    .padding(.bottom, 20)

                row(label: "Hotkey", explanation: "Push-to-talk trigger, held anywhere in macOS.") {
                    Text("⌥ Right Option").harpsType(HarpsType.metaSmall)
                }
                row(label: "Model", explanation: "The on-device engine used to transcribe.") {
                    Text("SpeechAnalyzer").harpsType(HarpsType.bodySmall)
                }
                row(label: "Insertion strategy", explanation: "How text lands at your cursor.") {
                    Text("Paste").harpsType(HarpsType.bodySmall)
                }
                row(label: "Transcript folder", explanation: "Where your dictated text is kept.") {
                    Button(model.transcriptsDirectory.path) {
                        NSWorkspace.shared.activateFileViewerSelecting([model.transcriptsDirectory])
                    }
                    .buttonStyle(.plain)
                    .harpsType(HarpsType.caption)
                    .foregroundColor(theme.textMuted)
                }
                row(label: "Launch at login", explanation: "Start Harps automatically when you sign in.") {
                    Toggle("", isOn: $settings.launchAtLogin).labelsHidden()
                }
                row(label: "Keep audio", explanation: "Debug aid. Off by default — audio has no use after transcription.") {
                    Toggle("", isOn: $settings.keepAudioForDebug).labelsHidden()
                }
                row(label: "Permissions", explanation: "Microphone, Speech Recognition, and Accessibility.") {
                    Button("Review…", action: model.onOpenSetup)
                }

                statement("Runs on device. Nothing leaves this Mac.")
                statement("Off by default. Audio has no use after transcription.")

                if !log.recentEntries.isEmpty {
                    Text("RECENT ACTIVITY")
                        .harpsType(HarpsType.section)
                        .foregroundColor(theme.textFaint)
                        .padding(.top, 24)
                        .padding(.bottom, 8)
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(log.recentEntries.prefix(20)) { entry in
                            HStack(alignment: .top, spacing: 8) {
                                Text(Self.timeFormatter.string(from: entry.date))
                                    .harpsType(HarpsType.meta)
                                    .foregroundColor(theme.textFaint)
                                Text(entry.message)
                                    .harpsType(HarpsType.caption)
                                    .foregroundColor(entry.level == .error ? theme.live : theme.textMuted)
                            }
                        }
                    }
                }
            }
            .padding(28)
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private func row<Control: View>(label: String, explanation: String, @ViewBuilder control: () -> Control) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .harpsType(HarpsType.bodyMedium)
                    .foregroundColor(theme.text)
                Text(explanation)
                    .harpsType(HarpsType.caption)
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
            .font(.custom("Geist-Medium", size: 12))
            .foregroundColor(theme.textMuted)
            .padding(.vertical, 10)
    }
}
