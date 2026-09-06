// Spike C — is on-device transcription fast enough, and accurate enough?
//
// The latency budget is release-to-text under 1.5s for a 10-second utterance.
// This records from the real microphone through the same AVAudioEngine path the
// app will use, then transcribes and reports wall clock and realtime factor.
//
//   swift run SpikeCTranscribe                 # record 10s, then transcribe
//   swift run SpikeCTranscribe --seconds 15
//   swift run SpikeCTranscribe --file take.wav
//
// The engine sits behind one protocol so swapping it is a single file. See the
// note at the bottom about SpeechAnalyzer.

import AVFoundation
import Speech
import Foundation

// MARK: - arguments

var seconds = 10.0
var inputFile: URL?
var args = Array(CommandLine.arguments.dropFirst())
while let flag = args.first {
    args.removeFirst()
    switch flag {
    case "--seconds": if let v = args.first, let n = Double(v) { seconds = n; args.removeFirst() }
    case "--file":    if let v = args.first { inputFile = URL(fileURLWithPath: v); args.removeFirst() }
    default: print("unknown flag \(flag)"); exit(1)
    }
}

// MARK: - engine

protocol TranscriptionEngine {
    var name: String { get }
    func prepare() async throws
    func transcribe(_ url: URL) async throws -> String
}

enum SpikeError: Error, CustomStringConvertible {
    case denied(String), failed(String)
    var description: String {
        switch self {
        case .denied(let s): return "permission denied: \(s)"
        case .failed(let s): return s
        }
    }
}

/// Apple's established on-device path. Chosen for the spike because it is
/// stable and definitely available — it gives a real number today.
/// SpeechAnalyzer is the successor; see the note at the bottom.
struct AppleOnDevice: TranscriptionEngine {
    let name = "SFSpeechRecognizer (on-device)"
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    func prepare() async throws {
        let status = await withCheckedContinuation { c in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) }
        }
        guard status == .authorized else { throw SpikeError.denied("speech recognition") }
        guard let recognizer, recognizer.isAvailable else { throw SpikeError.failed("recognizer unavailable") }
        guard recognizer.supportsOnDeviceRecognition else {
            throw SpikeError.failed("on-device recognition unsupported on this machine")
        }
    }

    func transcribe(_ url: URL) async throws -> String {
        guard let recognizer else { throw SpikeError.failed("no recognizer") }
        let request = SFSpeechURLRecognitionRequest(url: url)
        // The whole point. If this is false the audio goes to Apple's servers,
        // which would break the promise the app is built on.
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            recognizer.recognitionTask(with: request) { result, error in
                guard !resumed else { return }
                if let error { resumed = true; continuation.resume(throwing: error); return }
                if let result, result.isFinal {
                    resumed = true
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
}

// MARK: - recording

/// 16 kHz mono float is exactly what every speech engine wants, and converting
/// once at the tap is cheaper than resampling a whole buffer later.
func record(seconds: Double) async throws -> URL {
    let engine = AVAudioEngine()
    let input = engine.inputNode
    let inputFormat = input.outputFormat(forBus: 0)

    guard let target = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                     sampleRate: 16_000, channels: 1, interleaved: false),
          let converter = AVAudioConverter(from: inputFormat, to: target)
    else { throw SpikeError.failed("could not build a 16 kHz converter") }

    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("harps-spike-\(Int(Date().timeIntervalSince1970)).wav")
    let file = try AVAudioFile(forWriting: url, settings: target.settings,
                               commonFormat: .pcmFormatFloat32, interleaved: false)

    var peak: Float = 0
    input.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { buffer, _ in
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * 16_000 / inputFormat.sampleRate) + 64
        guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
        var supplied = false
        var err: NSError?
        converter.convert(to: out, error: &err) { _, status in
            if supplied { status.pointee = .noDataNow; return nil }
            supplied = true; status.pointee = .haveData; return buffer
        }
        if err == nil, out.frameLength > 0 {
            try? file.write(from: out)
            if let ch = out.floatChannelData?[0] {
                for i in 0..<Int(out.frameLength) { peak = max(peak, abs(ch[i])) }
            }
        }
    }

    engine.prepare()
    try engine.start()
    print("Recording \(Int(seconds))s — speak now.")
    for remaining in stride(from: Int(seconds), through: 1, by: -1) {
        print("  \(remaining)…", terminator: "\n")
        fflush(stdout)
        try await Task.sleep(nanoseconds: 1_000_000_000)
    }
    input.removeTap(onBus: 0)
    engine.stop()

    print(String(format: "\nPeak level %.3f%@", peak,
                 peak < 0.02 ? "  ← almost silent, check the input device" : ""))
    return url
}

// MARK: - run

let engine: TranscriptionEngine = AppleOnDevice()

do {
    print("Engine: \(engine.name)\n")
    try await engine.prepare()

    let url: URL
    if let inputFile {
        url = inputFile
        print("Using \(inputFile.lastPathComponent)\n")
    } else {
        url = try await record(seconds: seconds)
    }

    let asset = AVURLAsset(url: url)
    let duration = try await CMTimeGetSeconds(asset.load(.duration))

    let started = CFAbsoluteTimeGetCurrent()
    let text = try await engine.transcribe(url)
    let elapsed = CFAbsoluteTimeGetCurrent() - started

    print("\n─────────────────────────────────────────")
    print(text.isEmpty ? "(nothing recognised)" : text)
    print("─────────────────────────────────────────")
    print(String(format: "audio      %.1fs", duration))
    print(String(format: "transcribe %.3fs", elapsed))
    print(String(format: "realtime   %.1fx", duration / max(elapsed, 0.0001)))
    print(String(format: "budget     %@ (target: under 1.5s for a 10s utterance)",
                 elapsed < 1.5 ? "PASS" : "MISS"))
    print("\nfile \(url.path)")
    print("Keep it — run the same file through whisper.cpp to compare like for like.")
} catch {
    print("FAILED: \(error)")
    exit(1)
}

// ── On SpeechAnalyzer ────────────────────────────────────────────────────────
// PLAN.md's recommendation is SpeechAnalyzer / SpeechTranscriber, the macOS 26
// successor to the recogniser used above, which benchmarks ahead of Whisper
// Small at roughly a third of the compute.
//
// It is deliberately not wired up here. This spike is meant to produce a number
// on the first run, and a speculative API call that fails to compile produces
// nothing. Once the harness above is proven, add a second `TranscriptionEngine`
// conformance against the current SpeechAnalyzer docs and run both — the timing
// and reporting code is already engine-agnostic, so it is one new struct and
// one changed line at `let engine`.
