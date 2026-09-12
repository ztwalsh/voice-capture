import AVFoundation
import Speech
import SwiftUI

/// One of the three grants Harps needs, per PLAN.md Phase 5: "Onboarding
/// that walks through microphone and Accessibility permission with live
/// state detection." Speech Recognition is the third — PLAN.md's prose
/// only names two, but `Info.plist` already declares
/// `NSSpeechRecognitionUsageDescription` and the app cannot transcribe
/// without it, so leaving it out of onboarding would be an honesty gap.
enum PermissionKind: String, CaseIterable, Identifiable {
    case microphone = "Microphone"
    case speechRecognition = "Speech Recognition"
    case accessibility = "Accessibility"
    var id: String { rawValue }

    var explanation: String {
        switch self {
        case .microphone: return "Needed to hear you while you hold the hotkey."
        case .speechRecognition: return "Needed for on-device transcription. Nothing leaves this Mac."
        case .accessibility: return "Needed to insert text into whatever app you're using."
        }
    }

    /// Accessibility can't be requested with a normal dialog — PLAN.md calls
    /// this out explicitly. The other two use the standard system prompt.
    var requestsViaSystemPrompt: Bool { self != .accessibility }
}

enum PermissionState: Equatable {
    case granted
    case notDetermined
    case denied
}

/// Polls live permission state rather than caching it — PLAN.md's exit
/// criteria is explicitly about noticing a change without the user having
/// to relaunch anything, and there is no notification API for any of these
/// three that's simpler than a cheap poll.
@MainActor
final class OnboardingModel: ObservableObject {
    @Published var states: [PermissionKind: PermissionState] = [:]
    private var pollTask: Task<Void, Never>?

    var allGranted: Bool {
        PermissionKind.allCases.allSatisfy { states[$0] == .granted }
    }

    func startPolling() {
        refresh()
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                self.refresh()
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
    }

    private func refresh() {
        states[.microphone] = Self.microphoneState()
        states[.speechRecognition] = Self.speechState()
        states[.accessibility] = AXIsProcessTrusted() ? .granted : .denied
    }

    private static func microphoneState() -> PermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return .granted
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    private static func speechState() -> PermissionState {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return .granted
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    func request(_ kind: PermissionKind) {
        switch kind {
        case .microphone:
            AVCaptureDevice.requestAccess(for: .audio) { _ in Task { @MainActor [weak self] in self?.refresh() } }
        case .speechRecognition:
            SFSpeechRecognizer.requestAuthorization { _ in Task { @MainActor [weak self] in self?.refresh() } }
        case .accessibility:
            let promptKey = "AXTrustedCheckOptionPrompt" as CFString
            _ = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
        }
    }

    func openSystemSettings(for kind: PermissionKind) {
        let anchor: String
        switch kind {
        case .microphone: anchor = "Privacy_Microphone"
        case .speechRecognition: anchor = "Privacy_SpeechRecognition"
        case .accessibility: anchor = "Privacy_Accessibility"
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// PLAN.md: "Onboarding is a first-class feature, not a polish item." One
/// row per grant, live status, and the right action for how each kind of
/// permission is actually requested on macOS. Styled with the same
/// `WindowTheme`/`HarpsType` tokens as the history window rather than plain
/// system defaults — this is as much a real Harps surface as any other.
struct OnboardingView: View {
    @ObservedObject var model: OnboardingModel
    let onDone: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = WindowTheme(colorScheme)
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 10) {
                CaretMark()
                    .frame(width: 16, height: 16)
                    .padding(6)
                    .background(theme.text, in: RoundedRectangle(cornerRadius: 8))
                    .foregroundColor(theme.bg)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Set up Harps")
                        .harpsType(HarpsType.subtitle)
                        .foregroundColor(theme.text)
                    Text("Three permissions, granted once. Harps never sends anything off this Mac.")
                        .harpsType(HarpsType.caption)
                        .foregroundColor(theme.textSubtle)
                }
            }

            VStack(spacing: 0) {
                ForEach(PermissionKind.allCases) { kind in
                    row(for: kind, theme: theme)
                    if kind != PermissionKind.allCases.last {
                        Rectangle().frame(height: 1).foregroundColor(theme.hairline)
                    }
                }
            }
            .padding(4)
            .background(theme.trough, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(theme.hairline))

            HStack {
                Spacer()
                Button(model.allGranted ? "Done" : "I'll finish later", action: onDone)
                    .buttonStyle(HarpsPrimaryButtonStyle(theme: theme))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460)
        .background(theme.bg)
        .onAppear { model.startPolling() }
        .onDisappear { model.stopPolling() }
    }

    @ViewBuilder
    private func row(for kind: PermissionKind, theme: WindowTheme) -> some View {
        let state = model.states[kind] ?? .notDetermined
        HStack(spacing: 12) {
            statusIcon(state, theme: theme)
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.rawValue).harpsType(HarpsType.bodyMedium).foregroundColor(theme.text)
                Text(kind.explanation).harpsType(HarpsType.caption).foregroundColor(theme.textSubtle)
            }
            Spacer()
            actionButton(kind, state: state, theme: theme)
        }
        .padding(10)
        .animation(.easeOut(duration: 0.2), value: state)
    }

    @ViewBuilder
    private func statusIcon(_ state: PermissionState, theme: WindowTheme) -> some View {
        switch state {
        case .granted:
            Image(systemName: "checkmark.circle.fill").foregroundColor(theme.up)
        case .notDetermined:
            Image(systemName: "circle").foregroundColor(theme.textFaint)
        case .denied:
            Image(systemName: "exclamationmark.circle.fill").foregroundColor(theme.live)
        }
    }

    @ViewBuilder
    private func actionButton(_ kind: PermissionKind, state: PermissionState, theme: WindowTheme) -> some View {
        switch state {
        case .granted:
            EmptyView()
        case .notDetermined:
            Button("Grant") { model.request(kind) }
                .buttonStyle(HarpsSecondaryButtonStyle(theme: theme))
        case .denied:
            Button("Open Settings") { model.openSystemSettings(for: kind) }
                .buttonStyle(HarpsSecondaryButtonStyle(theme: theme))
        }
    }
}
