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

    /// The full welcome → permission-by-permission wizard is a one-time
    /// first-run story, not something a returning user (or a permission
    /// getting revoked later) should sit through again — a second Mac
    /// should feel like "oh right, grant the three things," not a replayed
    /// intro. `OnboardingWindowController` reads this to decide which view
    /// to show.
    static var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }

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
            CentralIconView(svg: CentralIcons.checkCircle, color: theme.up).frame(width: 15, height: 15)
        case .notDetermined:
            CentralIconView(svg: CentralIcons.circle, color: theme.textFaint).frame(width: 15, height: 15)
        case .denied:
            CentralIconView(svg: CentralIcons.exclamationCircle, color: theme.live).frame(width: 15, height: 15)
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

/// The first-run story `OnboardingView` never told: a welcome screen, then
/// one permission at a time (rather than all three dumped in a list at
/// once), each explained before it's requested. Confirmed live on a second
/// Mac that the flat checklist alone read as "lackluster" — no narrative,
/// nothing said what the app even does. This is shown exactly once per
/// install; `OnboardingWindowController` falls back to the plain
/// `OnboardingView` checklist for a returning user or a later-revoked
/// permission, where replaying a welcome screen would be patronizing.
private enum OnboardingStep: Equatable {
    case welcome
    case permission(PermissionKind)
    case allSet

    static var all: [OnboardingStep] {
        [.welcome] + PermissionKind.allCases.map(OnboardingStep.permission) + [.allSet]
    }
}

struct OnboardingWizardView: View {
    @ObservedObject var model: OnboardingModel
    let onDone: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    @State private var stepIndex = 0
    /// Guards against auto-advancing a second time on the same granted
    /// state — `states` publishes on every 1s poll tick, granted or not.
    @State private var hasAdvancedForCurrentStep = false

    private var steps: [OnboardingStep] { OnboardingStep.all }

    var body: some View {
        let theme = WindowTheme(colorScheme)
        VStack(spacing: 24) {
            progressDots(theme: theme)
            content(for: steps[stepIndex], theme: theme)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(28)
        .frame(width: 460, height: 400)
        .background(theme.bg)
        .onAppear { model.startPolling() }
        .onDisappear { model.stopPolling() }
        .onChange(of: model.states) { _, _ in autoAdvanceIfGranted() }
    }

    /// Only the permission steps get a dot — welcome/all-set are bookends,
    /// not part of the thing being counted.
    private func progressDots(theme: WindowTheme) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(PermissionKind.allCases.enumerated()), id: \.offset) { index, _ in
                Circle()
                    .fill(dotColor(for: index, theme: theme))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private func dotColor(for permissionIndex: Int, theme: WindowTheme) -> Color {
        guard case .permission = steps[stepIndex] else { return theme.sel }
        let currentPermissionIndex = stepIndex - 1
        if permissionIndex < currentPermissionIndex { return theme.up }
        if permissionIndex == currentPermissionIndex { return theme.text }
        return theme.sel
    }

    @ViewBuilder
    private func content(for step: OnboardingStep, theme: WindowTheme) -> some View {
        switch step {
        case .welcome: welcomeStep(theme: theme)
        case .permission(let kind): permissionStep(kind, theme: theme)
        case .allSet: allSetStep(theme: theme)
        }
    }

    private func welcomeStep(theme: WindowTheme) -> some View {
        VStack(spacing: 20) {
            Spacer()
            CaretMark()
                .frame(width: 22, height: 22)
                .padding(14)
                .background(theme.text, in: RoundedRectangle(cornerRadius: 14))
                .foregroundColor(theme.bg)
            VStack(spacing: 8) {
                Text("Welcome to Harps")
                    .harpsType(HarpsType.subtitle)
                    .foregroundColor(theme.text)
                Text("Hold a key, talk, it's already typed — in any app, entirely on this Mac.")
                    .harpsType(HarpsType.caption)
                    .foregroundColor(theme.textSubtle)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            Spacer()
            Button("Get Started") { advance() }
                .buttonStyle(HarpsPrimaryButtonStyle(theme: theme))
                .keyboardShortcut(.defaultAction)
        }
    }

    private func permissionStep(_ kind: PermissionKind, theme: WindowTheme) -> some View {
        let state = model.states[kind] ?? .notDetermined
        return VStack(spacing: 20) {
            Spacer()
            statusIcon(state, theme: theme)
                .frame(width: 15, height: 15)
                .padding(14)
                .background(theme.trough, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(theme.hairline))
            VStack(spacing: 8) {
                Text(kind.rawValue)
                    .harpsType(HarpsType.subtitle)
                    .foregroundColor(theme.text)
                Text(kind.explanation)
                    .harpsType(HarpsType.caption)
                    .foregroundColor(theme.textSubtle)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            Spacer()
            VStack(spacing: 10) {
                switch state {
                case .granted:
                    Button("Continue") { advance() }
                        .buttonStyle(HarpsPrimaryButtonStyle(theme: theme))
                        .keyboardShortcut(.defaultAction)
                case .notDetermined:
                    Button("Grant Access") { model.request(kind) }
                        .buttonStyle(HarpsPrimaryButtonStyle(theme: theme))
                        .keyboardShortcut(.defaultAction)
                    skipButton(theme: theme)
                case .denied:
                    Button("Open System Settings") { model.openSystemSettings(for: kind) }
                        .buttonStyle(HarpsPrimaryButtonStyle(theme: theme))
                        .keyboardShortcut(.defaultAction)
                    skipButton(theme: theme)
                }
            }
        }
        .onAppear { hasAdvancedForCurrentStep = false }
    }

    private func skipButton(theme: WindowTheme) -> some View {
        Button("I'll do this later") { advance() }
            .buttonStyle(.plain)
            .font(.custom("Geist-Regular", size: 12))
            .foregroundColor(theme.textFaint)
    }

    private func allSetStep(theme: WindowTheme) -> some View {
        VStack(spacing: 20) {
            Spacer()
            CentralIconView(svg: CentralIcons.checkCircle, color: theme.up)
                .frame(width: 22, height: 22)
                .padding(14)
                .background(theme.trough, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(theme.hairline))
            VStack(spacing: 8) {
                Text("You're all set")
                    .harpsType(HarpsType.subtitle)
                    .foregroundColor(theme.text)
                Text("Hold your hotkey anywhere and start talking.")
                    .harpsType(HarpsType.caption)
                    .foregroundColor(theme.textSubtle)
            }
            Spacer()
            Button("Start Using Harps") {
                OnboardingModel.hasCompletedOnboarding = true
                onDone()
            }
            .buttonStyle(HarpsPrimaryButtonStyle(theme: theme))
            .keyboardShortcut(.defaultAction)
        }
    }

    @ViewBuilder
    private func statusIcon(_ state: PermissionState, theme: WindowTheme) -> some View {
        switch state {
        case .granted:
            CentralIconView(svg: CentralIcons.checkCircle, color: theme.up)
        case .notDetermined:
            CentralIconView(svg: CentralIcons.circle, color: theme.textFaint)
        case .denied:
            CentralIconView(svg: CentralIcons.exclamationCircle, color: theme.live)
        }
    }

    private func advance() {
        guard stepIndex < steps.count - 1 else { return }
        withAnimation(.easeOut(duration: 0.2)) { stepIndex += 1 }
    }

    /// A granted permission auto-advances after a beat, so the happy path
    /// (grant, grant, grant) never needs an extra click on top of the
    /// system prompt itself.
    private func autoAdvanceIfGranted() {
        guard case .permission(let kind) = steps[stepIndex],
              model.states[kind] == .granted,
              !hasAdvancedForCurrentStep
        else { return }
        hasAdvancedForCurrentStep = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { advance() }
    }
}
