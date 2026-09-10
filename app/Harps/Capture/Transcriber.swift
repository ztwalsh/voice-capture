import Speech

enum TranscriberError: Error {
    case permissionDenied
    case onDeviceUnavailable
    case noResult
}

/// The seam PLAN.md calls for: whichever engine wins Spike C — this one,
/// SpeechAnalyzer, or Whisper — implements this and nothing else in the app
/// changes.
///
/// `Sendable` because `HarpsController` calls these from the main actor into a
/// `nonisolated async` context, so the conforming instance crosses actors.
protocol Transcriber: Sendable {
    func prepare() async throws
    func transcribe(fileAt url: URL) async throws -> String
}

/// `SFSpeechRecognizer` with on-device recognition forced on. This is the
/// same engine Spike C measures, not the SpeechAnalyzer/SpeechTranscriber
/// pair PLAN.md recommends as the eventual default — deliberately. This one
/// is stable and available today, so the walking skeleton produces a real
/// end-to-end result immediately. Swapping in SpeechAnalyzer once Spike C
/// confirms it is exactly one new type conforming to `Transcriber`.
///
/// `@unchecked Sendable`: `SFSpeechRecognizer` is not `Sendable` and
/// `activeTask` is mutable, but a single transcription runs at a time and only
/// `HarpsController`'s one `Task` ever calls in, so there is no concurrent
/// access to reason about.
final class OnDeviceTranscriber: Transcriber, @unchecked Sendable {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    // Held for the duration of the call. Nothing else keeps the task alive,
    // and letting it be deallocated mid-recognition is the kind of bug that
    // shows up as an occasional silent failure rather than a crash.
    private var activeTask: SFSpeechRecognitionTask?

    func prepare() async throws {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard status == .authorized else { throw TranscriberError.permissionDenied }
        guard let recognizer, recognizer.supportsOnDeviceRecognition else {
            throw TranscriberError.onDeviceUnavailable
        }
    }

    func transcribe(fileAt url: URL) async throws -> String {
        guard let recognizer else { throw TranscriberError.onDeviceUnavailable }
        let request = SFSpeechURLRecognitionRequest(url: url)

        // The whole point of this class. If this were false, audio would go
        // to Apple's servers, which breaks the promise the app is built on.
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            activeTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard !resumed else { return }
                if let error {
                    resumed = true
                    self?.activeTask = nil
                    continuation.resume(throwing: error)
                    return
                }
                if let result, result.isFinal {
                    resumed = true
                    self?.activeTask = nil
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
}
