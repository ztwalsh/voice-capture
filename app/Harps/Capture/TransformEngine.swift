import FoundationModels

/// PLAN.md Phase 6. Runs each enabled `Transform`'s instructions over the
/// raw transcript, in order, entirely on-device via Apple's Foundation
/// Models framework — the app already requires macOS 26 for
/// SpeechAnalyzer, so this adds no new minimum version.
enum TransformEngine {
    /// Never blocks a capture on this feature: unavailable Apple
    /// Intelligence, or any one transform failing, just passes the text
    /// through unchanged rather than losing it or hanging the insertion.
    /// Confirmed live that the unavailable case needs to actually say so —
    /// it previously returned silently, which is indistinguishable from
    /// "nothing enabled" or a real bug from the outside.
    static func apply(_ transforms: [Transform], to text: String) async -> String {
        guard case .available = SystemLanguageModel.default.availability else {
            await AppLog.shared.error("Transforms skipped — \(availabilityDescription())")
            return text
        }

        var current = text
        for transform in transforms {
            do {
                let session = LanguageModelSession(instructions: Self.systemInstructions)
                let prompt = """
                Rule: \(transform.instructions)

                Transcript:
                \(current)
                """
                let response = try await session.respond(to: prompt)
                current = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                await AppLog.shared.error("Transform \"\(transform.name)\" failed: \(error.localizedDescription)")
                // Keep `current` as it was going into this transform and
                // move on to the next one — one bad transform should never
                // lose the whole capture.
            }
        }
        return current
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
