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
/// site, so there is no concurrent access to the mutable `modelReady`
/// property to reason about.
final class SpeechAnalyzerTranscriber: Transcriber, @unchecked Sendable {
    private let locale = Locale(identifier: "en-US")

    /// Whether the on-device model is confirmed installed. This — not a
    /// `SpeechTranscriber` instance — is the thing worth caching across
    /// captures.
    ///
    /// This used to cache the `SpeechTranscriber` itself and hand the same
    /// instance to a new `SpeechAnalyzer` on every capture. That crashed
    /// live, repeatedly, inside Apple's own framework
    /// (`SpeechAnalyzer.setWorkers(for:reusingFrom:preservingFunctionOf:)`
    /// → `TranscriberCommon.worker.setter`) — the `reusingFrom` parameter is
    /// literally the analyzer trying to hand off worker state from the
    /// previous analyzer generation that used the same transcriber module,
    /// and that handoff path is what breaks, even for two sequential,
    /// non-overlapping captures (a separate `isTranscribing` guard already
    /// rules out two *concurrent* transcriptions — this crash kept
    /// happening anyway, because the bug is in cross-generation reuse, not
    /// concurrency). Building a fresh `SpeechTranscriber` per capture
    /// avoids that code path entirely: each `SpeechAnalyzer` then owns a
    /// module no other analyzer has ever touched. The actually-expensive
    /// part of the old `prepare()` — checking supported/installed locales
    /// and installing the asset — doesn't depend on a specific
    /// `SpeechTranscriber` instance, so it's still only ever done once.
    private var modelReady = false

    func prepare() async throws {
        guard !modelReady else { return }
        // `.transcription` (the preset this used) doesn't request
        // `.fastResults` — confirmed against Speech.framework's own
        // `SpeechTranscriber.ReportingOption` enum, which has `.fastResults`
        // as an explicit, opt-in-only lever for lower-latency output.
        // Alternatives/audio-time-ranges/confidence scores are all things
        // this app never reads (only `result.text`), so there's nothing to
        // lose by leaving `transcriptionOptions`/`attributeOptions` empty too.
        let probe = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.fastResults],
            attributeOptions: []
        )
        try await Self.ensureModelInstalled(for: probe, locale: locale)
        modelReady = true
    }

    func transcribe(fileAt url: URL) async throws -> String {
        guard modelReady else { throw TranscriberError.onDeviceUnavailable }
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.fastResults],
            attributeOptions: []
        )
        let audioFile = try AVAudioFile(forReading: url)

        // `finishAfterFile: true` drives the whole file through and closes
        // `transcriber.results` when it reaches the end — no manual
        // analyze/finalize bookkeeping needed for a batch, non-live file.
        let analyzer = try await SpeechAnalyzer(inputAudioFile: audioFile,
                                                 modules: [transcriber],
                                                 finishAfterFile: true)

        var text = ""
        for try await result in transcriber.results {
            text += String(result.text.characters)
        }
        // `analyzer` has no other reference after this point — without this,
        // Swift's lexical lifetimes could release (and start tearing down)
        // it as soon as its last syntactic use above, potentially before
        // the results stream has actually finished draining.
        withExtendedLifetime(analyzer) {}
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
