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
                        .font(.system(size: 9.5, design: .monospaced))
                        .tracking(1.2)
                        .foregroundColor(theme.textFaint)
                        .padding(.top, 24)
                        .padding(.bottom, 8)
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(log.recentEntries.prefix(20)) { entry in
                            HStack(alignment: .top, spacing: 8) {
                                Text(Self.timeFormatter.string(from: entry.date))
                                    .font(.system(size: 10.5, design: .monospaced))
                                    .foregroundColor(theme.textFaint)
                                Text(entry.message)
                                    .font(.system(size: 11.5))
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
