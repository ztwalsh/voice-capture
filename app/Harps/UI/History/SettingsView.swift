import SwiftUI

/// design.md §7: "Label, one-line explanation, and a control. Rows
/// separated by hairlines." Hotkey/model/insertion strategy have exactly
/// one implementation each, so they're shown as honest, informational
/// values in a mono chip — PLAN.md's real Phase 5 settings, launch-at-login
/// and keep-audio, are genuine controls using the app's own styled switch
/// rather than a system checkbox. Centered with the same 700px measure as
/// the Document reading view, per direct request — design.md's own 620px
/// wasn't matched here on purpose.
struct SettingsView: View {
    @ObservedObject var model: HistoryViewModel
    let theme: WindowTheme
    @ObservedObject private var settings = SettingsStore.shared
    @ObservedObject private var log = AppLog.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                row(label: "Hotkey", explanation: "Push-to-talk trigger, held anywhere in macOS.") {
                    HarpsDropdown(
                        titles: ModifierHotkey.allCases.map(\.label),
                        selected: settings.hotkey.label,
                        theme: theme
                    ) { title in
                        if let match = ModifierHotkey.allCases.first(where: { $0.label == title }) {
                            settings.hotkey = match
                        }
                    }
                    .fixedSize()
                }
                row(label: "Appearance", explanation: "Light, dark, or match the system.") {
                    SegmentedPicker(options: AppAppearance.allCases, label: \.label,
                                     selection: $settings.appearance, theme: theme)
                }
                row(label: "Auto-delete", explanation: "Remove day files older than this, checked at launch.") {
                    SegmentedPicker(options: RetentionPeriod.allCases, label: \.label,
                                     selection: $settings.retention, theme: theme)
                }
                row(label: "Model", explanation: "Runs on device. Nothing leaves this Mac.") {
                    SettingsValueChip(text: "SpeechAnalyzer", theme: theme)
                }
                row(label: "Insertion", explanation: "How text reaches the focused field.") {
                    SettingsValueChip(text: "Paste", theme: theme)
                }
                row(label: "Keep audio", explanation: "Off by default. Audio has no use after transcription.") {
                    Toggle("", isOn: $settings.keepAudioForDebug)
                        .labelsHidden()
                        .toggleStyle(HarpsToggleStyle(theme: theme))
                }
                row(label: "Launch at login", explanation: nil) {
                    Toggle("", isOn: $settings.launchAtLogin)
                        .labelsHidden()
                        .toggleStyle(HarpsToggleStyle(theme: theme))
                }
                row(label: "Transcript folder", explanation: model.transcriptsDirectory.path) {
                    HStack(spacing: 6) {
                        Button("Change…", action: chooseTranscriptsDirectory)
                            .buttonStyle(HarpsSecondaryButtonStyle(theme: theme))
                        Button("Show in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([model.transcriptsDirectory])
                        }
                        .buttonStyle(HarpsSecondaryButtonStyle(theme: theme))
                    }
                }
                row(label: "Permissions", explanation: "Microphone, Speech Recognition, and Accessibility.") {
                    Button("Review…", action: model.onOpenSetup)
                        .buttonStyle(HarpsSecondaryButtonStyle(theme: theme))
                }

                if !log.recentEntries.isEmpty {
                    Text("RECENT ACTIVITY")
                        .harpsType(HarpsType.section)
                        .foregroundColor(theme.textFaint)
                        .padding(.top, 30)
                        .padding(.bottom, 10)
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
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
            .padding(.top, 26)
            .padding(.bottom, 60)
            .padding(.horizontal, 22)
            .background(ScrollbarHider())
        }
        .scrollIndicators(.hidden)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    /// Moving folders, not copying: an existing history at the old location
    /// stays there untouched, since silently relocating a person's own
    /// files without asking is exactly the kind of thing design.md's "the
    /// file is the source of truth" promise should never do quietly.
    private func chooseTranscriptsDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Choose where Harps keeps your transcripts. Existing files stay where they are."
        panel.directoryURL = model.transcriptsDirectory
        guard panel.runModal() == .OK, let url = panel.urls.first else { return }
        settings.customTranscriptsDirectory = url
        model.reload()
    }

    private func row<Control: View>(label: String, explanation: String?,
                                     @ViewBuilder control: () -> Control) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.custom("Geist-Regular", size: 13.5))
                    .foregroundColor(theme.text)
                if let explanation {
                    Text(explanation)
                        .font(.custom("Geist-Regular", size: 11.5))
                        .foregroundColor(theme.textSubtle)
                }
            }
            Spacer()
            control()
        }
        .padding(.vertical, 15)
        .overlay(Rectangle().frame(height: 1).foregroundColor(theme.hairline), alignment: .bottom)
    }
}

/// A segmented control for any small `CaseIterable` option set — the same
/// pill language as `TranscriptsPillTabs`, sized down to fit a settings
/// row. Shared by Appearance and Auto-delete rather than one bespoke view
/// per enum.
private struct SegmentedPicker<Option: Identifiable & Hashable>: View {
    let options: [Option]
    let label: (Option) -> String
    @Binding var selection: Option
    let theme: WindowTheme
    @Namespace private var pillNamespace

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options) { option in
                let selected = selection == option
                Button {
                    withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.25)) {
                        selection = option
                    }
                } label: {
                    Text(label(option))
                        .font(.custom(selected ? "Geist-Medium" : "Geist-Regular", size: 12))
                        .foregroundColor(selected ? theme.text : theme.textMuted)
                        .padding(.horizontal, 11)
                        .frame(height: 24)
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
