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
/// permission is actually requested on macOS.
struct OnboardingView: View {
    @ObservedObject var model: OnboardingModel
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Set up Harps")
                    .font(.system(size: 17, weight: .semibold))
                Text("Three permissions, granted once. Harps never sends anything off this Mac.")
                    .font(.system(size: 12.5))
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(PermissionKind.allCases) { kind in
                    row(for: kind)
                    if kind != PermissionKind.allCases.last {
                        Divider()
                    }
                }
            }
            .padding(4)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))

            HStack {
                Spacer()
                Button(model.allGranted ? "Done" : "I'll finish later", action: onDone)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460)
        .onAppear { model.startPolling() }
        .onDisappear { model.stopPolling() }
    }

    @ViewBuilder
    private func row(for kind: PermissionKind) -> some View {
        let state = model.states[kind] ?? .notDetermined
        HStack(spacing: 12) {
            statusIcon(state)
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.rawValue).font(.system(size: 13, weight: .medium))
                Text(kind.explanation).font(.system(size: 11)).foregroundColor(.secondary)
            }
            Spacer()
            actionButton(kind, state: state)
        }
        .padding(10)
    }

    @ViewBuilder
    private func statusIcon(_ state: PermissionState) -> some View {
        switch state {
        case .granted:
            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
        case .notDetermined:
            Image(systemName: "circle").foregroundColor(.secondary)
        case .denied:
            Image(systemName: "exclamationmark.circle.fill").foregroundColor(.orange)
        }
    }

    @ViewBuilder
    private func actionButton(_ kind: PermissionKind, state: PermissionState) -> some View {
        switch state {
        case .granted:
            EmptyView()
        case .notDetermined:
            Button("Grant") { model.request(kind) }
        case .denied:
            Button("Open Settings") { model.openSystemSettings(for: kind) }
        }
    }
}
