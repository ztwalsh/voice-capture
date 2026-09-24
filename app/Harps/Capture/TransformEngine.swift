import FoundationModels

/// PLAN.md Phase 6. Runs each enabled `Transform`'s instructions over the
/// raw transcript, in order, entirely on-device via Apple's Foundation
/// Models framework — the app already requires macOS 26 for
/// SpeechAnalyzer, so this adds no new minimum version.
///
/// `@MainActor`: `warmSession` is mutable state read and written across
/// `apply(_:to:)` calls; every call site is already on the main actor (the
/// `Task { @MainActor in ... }` in `HarpsController.endCapture()`), so this
/// just makes that explicit instead of leaving the class racy on paper.
@MainActor
enum TransformEngine {
    /// A `LanguageModelSession` that has already paid its session-creation
    /// cost, ready for the next capture. Measured live: creating a fresh
    /// `LanguageModelSession` and calling `respond(to:)` on it costs
    /// ~4-10s regardless of prompt length — reusing an already-warm session
    /// for a second call on the same instance dropped that to ~0.7s. This
    /// was the actual source of "transcription feels slow" once the Speech
    /// side was already fast: `apply` used to build a brand-new session
    /// per transform per capture, paying that cold-session cost every
    /// single time.
    private static var warmSession: LanguageModelSession?

    /// Never blocks a capture on this feature: unavailable Apple
    /// Intelligence, or any one transform failing, just passes the text
    /// through unchanged rather than losing it or hanging the insertion.
    /// Confirmed live that the unavailable case needs to actually say so —
    /// it previously returned silently, which is indistinguishable from
    /// "nothing enabled" or a real bug from the outside.
    static func apply(_ transforms: [Transform], to text: String) async -> String {
        guard !transforms.isEmpty else { return text }
        guard case .available = SystemLanguageModel.default.availability else {
            AppLog.shared.error("Transforms skipped — \(availabilityDescription())")
            return text
        }

        let session = warmSession ?? LanguageModelSession(instructions: Self.systemInstructions)

        var current = text
        for transform in transforms {
            do {
                let prompt = """
                Rule: \(transform.instructions)

                Transcript:
                \(current)
                """
                let response = try await session.respond(to: prompt)
                current = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                AppLog.shared.error("Transform \"\(transform.name)\" failed: \(error.localizedDescription)")
                // Keep `current` as it was going into this transform and
                // move on to the next one — one bad transform should never
                // lose the whole capture.
            }
        }

        // This session now carries this capture's transcript(s) as
        // conversation history. Rather than let that grow unbounded across
        // every future capture for as long as Harps stays open (the whole
        // point of this app) — or bleed one capture's content into how the
        // model treats an unrelated later one — retire it and warm its
        // replacement now, off the critical path, so it's already ready
        // before the next capture needs it instead of paying the cold-
        // session cost again on the next `apply` call.
        warmSession = nil
        Task { await Self.warmUp() }

        return current
    }

    /// Builds and pre-warms a fresh session, then publishes it for the next
    /// `apply(_:to:)` call to pick up. Called once at launch (mirroring
    /// `Transcriber.prepare()`) and again after every capture that used a
    /// transform.
    static func warmUp() async {
        guard case .available = SystemLanguageModel.default.availability else { return }
        let session = LanguageModelSession(instructions: Self.systemInstructions)
        session.prewarm()
        warmSession = session
    }

    /// Confirmed live that `LanguageModelSession(instructions:)` alone,
    /// fed the raw transcript as the prompt, isn't enough: the model reads
    /// a dictated sentence as a chat message and *answers* it ("Sure, I'd
    /// be happy to help you test this out...") instead of transforming it.
    /// This fixed system framing, plus wrapping each call's actual work in
    /// an explicit "Rule / Transcript" prompt (below) rather than handing
    /// over the transcript bare, is what makes it behave like a pure
    /// text-in/text-out function instead of an assistant being chatted at.
    private static let systemInstructions = """
    You are a silent text-transformation tool embedded in a dictation app. \
    You are never a conversational assistant: you never answer questions, \
    never react to or comment on content, and never add a greeting, \
    preamble, or sign-off. Each request gives you a rule and a transcript. \
    Apply the rule to the transcript and output only the resulting \
    transcript text, exactly as it should replace the original — nothing \
    else.
    """

    /// Human-readable form of `SystemLanguageModel.default.availability` —
    /// shared by the log message above and `TransformsView`'s notice, so
    /// both ever say the same thing.
    static func availabilityDescription() -> String {
        switch SystemLanguageModel.default.availability {
        case .available:
            return "Apple Intelligence is available."
        case .unavailable(.deviceNotEligible):
            return "This Mac isn't eligible for Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Apple Intelligence is turned off — enable it in System Settings → Apple Intelligence & Siri."
        case .unavailable(.modelNotReady):
            return "Apple Intelligence's on-device model is still downloading or preparing — try again shortly."
        @unknown default:
            // `UnavailableReason` isn't `@frozen`, unlike `Availability`
            // itself — a future OS could add a case this app doesn't know
            // about yet, confirmed by the compiler rejecting an
            // exhaustive-looking switch without this.
            return "Apple Intelligence isn't available right now."
        }
    }

    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }
}
