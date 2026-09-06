import AVFoundation

enum AudioRecorderError: Error {
    case noConverter
    case engineFailed(Error)
}

/// Records from the default input device and writes 16 kHz mono float32 to a
/// temporary file — the format every speech engine wants, so the conversion
/// happens once at the tap instead of being redone downstream.
///
/// This is Spike C's recording path unchanged. It proved out the conversion
/// math; the walking skeleton just gives it a start/stop lifecycle instead of
/// a fixed countdown.
final class AudioRecorder {
    private let engine = AVAudioEngine()
    private var file: AVAudioFile?
    private(set) var peakLevel: Float = 0

    /// Called ~20 times a second while recording, with amplitude 0...1.
    /// The walking skeleton's rectangle does nothing with this; it exists
    /// because the panel in Phase 3 needs it and the tap is the only place
    /// to compute it cheaply.
    var onLevel: ((Float) -> Void)?

    func start() throws -> URL {
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)

        guard let target = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                          sampleRate: 16_000, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: inputFormat, to: target)
        else { throw AudioRecorderError.noConverter }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("harps-\(UUID().uuidString).wav")
        let file = try AVAudioFile(forWriting: url, settings: target.settings,
                                    commonFormat: .pcmFormatFloat32, interleaved: false)
        self.file = file

        peakLevel = 0
        input.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.convertAndWrite(buffer, format: inputFormat, target: target, converter: converter, file: file)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw AudioRecorderError.engineFailed(error)
        }
        return url
    }

    /// Returns the recorded duration. The caller decides what "too short to
    /// contain speech" means — this just reports the fact.
    @discardableResult
    func stop() -> TimeInterval {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        let duration = (file?.length ?? 0) > 0
            ? Double(file!.length) / file!.fileFormat.sampleRate
            : 0
        file = nil
        return duration
    }

    private func convertAndWrite(_ buffer: AVAudioPCMBuffer, format: AVAudioFormat,
                                  target: AVAudioFormat, converter: AVAudioConverter,
                                  file: AVAudioFile) {
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * 16_000 / format.sampleRate) + 64
        guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }

        var supplied = false
        var conversionError: NSError?
        converter.convert(to: out, error: &conversionError) { _, status in
            if supplied { status.pointee = .noDataNow; return nil }
            supplied = true
            status.pointee = .haveData
            return buffer
        }
        guard conversionError == nil, out.frameLength > 0 else { return }

        try? file.write(from: out)

        if let channel = out.floatChannelData?[0] {
            var peak: Float = 0
            for i in 0..<Int(out.frameLength) { peak = max(peak, abs(channel[i])) }
            peakLevel = peak
            onLevel?(peak)
        }
    }
}
