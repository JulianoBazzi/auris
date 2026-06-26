import Foundation
import AVFoundation
import ScreenCaptureKit

enum CaptureState: Equatable {
    case idle, recording, paused, finished
}

protocol AudioCapturing: AnyObject {
    var state: CaptureState { get }
    /// Called on the main actor with the latest input level (0...1) for the waveform.
    var onLevel: ((Float) -> Void)? { get set }
    /// Forwards microphone PCM buffers (mono, native format) to the transcription service.
    var onBuffer: ((AVAudioPCMBuffer) -> Void)? { get set }
    /// Forwards system-audio PCM buffers (mono) to a second transcription stream.
    var onSystemBuffer: ((AVAudioPCMBuffer) -> Void)? { get set }
    /// Non-fatal: system-audio (ScreenCaptureKit) capture failed; recording continues mic-only.
    var onSystemCaptureError: ((Error) -> Void)? { get set }
    func start(captureMic: Bool, captureSystem: Bool, fileName: String) async throws
    func pause()
    func resume()
    func stop() async -> URL?
}

/// Records the microphone (AVAudioEngine) and system audio (ScreenCaptureKit) into a single
/// .m4a file. System-audio buffers are scheduled onto a player node connected to the engine's
/// main mixer, and the mixer output is written to disk.
final class AudioCaptureService: NSObject, AudioCapturing, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    private(set) var state: CaptureState = .idle
    var onLevel: ((Float) -> Void)?
    var onBuffer: ((AVAudioPCMBuffer) -> Void)?
    var onSystemBuffer: ((AVAudioPCMBuffer) -> Void)?
    var onSystemCaptureError: ((Error) -> Void)?

    private let engine = AVAudioEngine()
    private let systemPlayer = AVAudioPlayerNode()
    /// Dedicated sub-mixer that mic + system audio feed into. We tap THIS node (not the main
    /// mixer) and mute the main mixer's output, so the recording captures everything while
    /// nothing is monitored back through the speakers (no echo / feedback).
    private let captureMixer = AVAudioMixerNode()
    private var stream: SCStream?
    private var audioFile: AVAudioFile?
    private var outputURL: URL?
    private let writeQueue = DispatchQueue(label: "com.bazzi.auris.audiowrite")
    private let sysFormat = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!
    private var sysConverter: AVAudioConverter?
    /// Mono format used to feed system audio to its own speech-recognition stream.
    private let monoFormat = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!
    private var monoConverter: AVAudioConverter?

    func start(captureMic: Bool, captureSystem: Bool, fileName: String) async throws {
        let url = RecordingStore.recordingURL(named: fileName)
        outputURL = url

        let mainMixer = engine.mainMixerNode
        let input = engine.inputNode
        let micFormat = input.outputFormat(forBus: 0)
        let hasMic = captureMic && micFormat.channelCount > 0 && micFormat.sampleRate > 0

        // Canonical processing format used consistently for the capture-mixer connection, the tap
        // and the output file. A mismatch here is what raised the CreateRecordingTap exception.
        let rate = micFormat.sampleRate > 0 ? micFormat.sampleRate : 48_000
        guard let tapFormat = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2) else {
            throw NSError(domain: "Auris.Audio", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "No valid audio output format available."])
        }

        // Build the graph BEFORE installing the tap so the mixer has a valid output format.
        // mic + systemPlayer -> captureMixer (tapped) -> mainMixer (muted output).
        engine.attach(systemPlayer)
        engine.attach(captureMixer)
        engine.connect(systemPlayer, to: captureMixer, format: sysFormat)
        if hasMic {
            engine.connect(input, to: captureMixer, format: micFormat)
        }
        // The captureMixer must still reach an output node for the graph to render, but we mute
        // the main mixer so the user never hears their own mic / the system audio (no echo).
        // Connect with the explicit processing format so the mixer's output bus is well-defined
        // and the tap below always matches it.
        engine.connect(captureMixer, to: mainMixer, format: tapFormat)
        mainMixer.outputVolume = 0
        engine.prepare()

        audioFile = try AVAudioFile(
            forWriting: url,
            settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: tapFormat.sampleRate,
                AVNumberOfChannelsKey: tapFormat.channelCount,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
        )

        // Tap the capture mixer for the FILE (mic + system mixed) and the waveform level.
        captureMixer.installTap(onBus: 0, bufferSize: 4096, format: tapFormat) { [weak self] buffer, _ in
            guard let self else { return }
            self.writeQueue.async { try? self.audioFile?.write(from: buffer) }
            let level = Self.peakLevel(buffer)
            DispatchQueue.main.async { self.onLevel?(level) }
        }

        // Tap the mic input directly in its native (mono) format for transcription. Feeding the
        // recognizer the stereo mixer buffer makes SFSpeech fail silently; the raw mic buffer works.
        if hasMic {
            input.installTap(onBus: 0, bufferSize: 4096, format: micFormat) { [weak self] buffer, _ in
                self?.onBuffer?(buffer)
            }
        }

        try engine.start()
        systemPlayer.play()

        // System audio is best-effort: if Screen Recording permission is missing or the API
        // fails, keep recording the microphone instead of aborting the whole session.
        if captureSystem {
            do {
                try await startSystemCapture()
            } catch {
                onSystemCaptureError?(error)
            }
        }

        state = .recording
    }

    private func startSystemCapture() async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else { return }
        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])

        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 48_000
        config.channelCount = 2
        // Minimal video config (required even when we only want audio).
        config.width = 2
        config.height = 2

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: writeQueue)
        try await stream.startCapture()
        self.stream = stream
    }

    func pause() {
        guard state == .recording else { return }
        engine.pause()
        state = .paused
    }

    func resume() {
        guard state == .paused else { return }
        try? engine.start()
        state = .recording
    }

    func stop() async -> URL? {
        if let stream { try? await stream.stopCapture() }
        stream = nil
        captureMixer.removeTap(onBus: 0)
        engine.inputNode.removeTap(onBus: 0)
        systemPlayer.stop()
        engine.stop()
        audioFile = nil
        sysConverter = nil
        monoConverter = nil
        state = .finished
        return outputURL
    }

    // MARK: - SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio,
              let pcm = Self.pcmBuffer(from: sampleBuffer),
              engine.isRunning, systemPlayer.engine != nil else { return }

        // The player node expects `sysFormat`; the incoming format may differ (sample rate,
        // interleaving). Convert defensively so scheduleBuffer never asserts on a mismatch.
        guard let converted = convertToSysFormat(pcm) else { return }
        systemPlayer.scheduleBuffer(converted, completionHandler: nil)

        // Feed a mono copy to the system-audio transcription stream.
        if let mono = convertToMono(pcm) { onSystemBuffer?(mono) }
    }

    private func convertToMono(_ input: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        if monoConverter == nil || monoConverter?.inputFormat != input.format {
            monoConverter = AVAudioConverter(from: input.format, to: monoFormat)
        }
        guard let converter = monoConverter else { return nil }
        let ratio = monoFormat.sampleRate / input.format.sampleRate
        let capacity = AVAudioFrameCount(Double(input.frameLength) * ratio) + 1024
        guard let output = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: capacity) else { return nil }
        var fed = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if fed { status.pointee = .noDataNow; return nil }
            fed = true
            status.pointee = .haveData
            return input
        }
        return error == nil && output.frameLength > 0 ? output : nil
    }

    private func convertToSysFormat(_ input: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        if input.format == sysFormat { return input }
        if sysConverter == nil || sysConverter?.inputFormat != input.format {
            sysConverter = AVAudioConverter(from: input.format, to: sysFormat)
        }
        guard let converter = sysConverter else { return nil }
        let ratio = sysFormat.sampleRate / input.format.sampleRate
        let capacity = AVAudioFrameCount(Double(input.frameLength) * ratio) + 1024
        guard let output = AVAudioPCMBuffer(pcmFormat: sysFormat, frameCapacity: capacity) else { return nil }
        var fed = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if fed { status.pointee = .noDataNow; return nil }
            fed = true
            status.pointee = .haveData
            return input
        }
        return error == nil && output.frameLength > 0 ? output : nil
    }

    // MARK: - Helpers

    private static func pcmBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let desc = sampleBuffer.formatDescription,
              let asbd = desc.audioStreamBasicDescription else { return nil }
        var format = asbd
        guard let avFormat = AVAudioFormat(streamDescription: &format) else { return nil }
        let frames = AVAudioFrameCount(sampleBuffer.numSamples)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: avFormat, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames
        CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer, at: 0, frameCount: Int32(frames), into: buffer.mutableAudioBufferList
        )
        return buffer
    }

    private static func peakLevel(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        let n = Int(buffer.frameLength)
        var peak: Float = 0
        for i in 0..<n { peak = max(peak, abs(channel[i])) }
        return min(peak * 1.5, 1)
    }
}
