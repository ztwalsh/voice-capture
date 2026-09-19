import Speech
import AVFoundation

/// Apple's newer speech engine — `SpeechAnalyzer` / `SpeechTranscriber`,
/// introduced alongside macOS 26 and PLAN.md's actual recommended default.
/// Spike C shipped with `SFSpeechRecognizer` instead because it produced a
/// real number immediately and was the stable choice at the time; this is
/// the swap PLAN.md always expected, pulled forward from "later" because
/// `SFSpeechRecognizer` turned out to silently drop everything spoken before
/// a mid-recording pause — it appears to treat a pause as an utterance
/// boundary and resets its running hypothesis, so the "final" transcript
/// only covers the last segment. `SpeechAnalyzer` is built for exactly
/// this — long-form, non-live transcription — and should not have that
/// failure mode.
///
/// `@unchecked Sendable`: same reasoning as `OnDeviceTranscriber` — a single
/// transcription runs at a time, driven from `HarpsController`'s one call
/// site, so there is no concurrent access to the mutable `transcriber`
/// property to reason about.
final class SpeechAnalyzerTranscriber: Transcriber, @unchecked Sendable {
    private let locale = Locale(identifier: "en-US")
    private var transcriber: SpeechTranscriber?

    func prepare() async throws {
        // Was rebuilding `SpeechTranscriber` and re-running the installed-
        // locales/asset-inventory check on every single capture, since
        // `HarpsController` calls `prepare()` before each `transcribe(fileAt:)`
        // — a real, measurable chunk of the per-capture latency users
        // noticed, for work whose result can't change between one capture
        // and the next in the same run. Building it once and reusing it is
        // safe: `transcriber` itself is just config the analyzer reads from,
        // not something tied to a single audio file.
        guard transcriber == nil else { return }
        // `.transcription` (the preset this used) doesn't request
        // `.fastResults` — confirmed against Speech.framework's own
        // `SpeechTranscriber.ReportingOption` enum, which has `.fastResults`
        // as an explicit, opt-in-only lever for lower-latency output.
        // Alternatives/audio-time-ranges/confidence scores are all things
        // this app never reads (only `result.text`), so there's nothing to
        // lose by leaving `transcriptionOptions`/`attributeOptions` empty too.
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.fastResults],
            attributeOptions: []
        )
        try await Self.ensureModelInstalled(for: transcriber, locale: locale)
        self.transcriber = transcriber
    }

    func transcribe(fileAt url: URL) async throws -> String {
        guard let transcriber else { throw TranscriberError.onDeviceUnavailable }
        let audioFile = try AVAudioFile(forReading: url)

        // `finishAfterFile: true` drives the whole file through and closes
        // `transcriber.results` when it reaches the end — no manual
        // analyze/finalize bookkeeping needed for a batch, non-live file.
        let analyzer = try await SpeechAnalyzer(inputAudioFile: audioFile,
                                                 modules: [transcriber],
                                                 finishAfterFile: true)
        _ = analyzer

        var text = ""
        for try await result in transcriber.results {
            text += String(result.text.characters)
        }
        return text
    }

    private static func ensureModelInstalled(for transcriber: SpeechTranscriber, locale: Locale) async throws {
        let supported = await SpeechTranscriber.supportedLocales
        guard supported.contains(where: { $0.identifier(.bcp47) == locale.identifier(.bcp47) }) else {
            throw TranscriberError.onDeviceUnavailable
        }
        let installed = await Set(SpeechTranscriber.installedLocales)
        guard !installed.contains(where: { $0.identifier(.bcp47) == locale.identifier(.bcp47) }) else { return }
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
    }
}
