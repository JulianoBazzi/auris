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
    /// Forwards mixed PCM buffers (e.g. to the transcription service).
    var onBuffer: ((AVAudioPCMBuffer) -> Void)? { get set }
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

    private let engine = AVAudioEngine()
    private let systemPlayer = AVAudioPlayerNode()
    private var stream: SCStream?
    private var audioFile: AVAudioFile?
    private var outputURL: URL?
    private let writeQueue = DispatchQueue(label: "com.bazzi.auris.audiowrite")

    func start(captureMic: Bool, captureSystem: Bool, fileName: String) async throws {
        let url = RecordingStore.recordingURL(named: fileName)
        outputURL = url

        let mixer = engine.mainMixerNode
        let input = engine.inputNode
        let micFormat = input.outputFormat(forBus: 0)
        let hasMic = captureMic && micFormat.channelCount > 0 && micFormat.sampleRate > 0

        // Build the graph BEFORE installing the tap so the mixer has a valid output format.
        engine.attach(systemPlayer)
        let sysFormat = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)
        engine.connect(systemPlayer, to: mixer, format: sysFormat)
        if hasMic {
            engine.connect(input, to: mixer, format: micFormat)
        }
        engine.prepare()

        // Use the mixer's real output format for both the tap and the file so they always match
        // (passing a mismatched/nil format here is what raised the CreateRecordingTap exception).
        let tapFormat = mixer.outputFormat(forBus: 0)
        guard tapFormat.sampleRate > 0, tapFormat.channelCount > 0 else {
            throw NSError(domain: "Auris.Audio", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "No valid audio output format available."])
        }

        audioFile = try AVAudioFile(
            forWriting: url,
            settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: tapFormat.sampleRate,
                AVNumberOfChannelsKey: tapFormat.channelCount,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
        )

        // Tap the main mixer so mic + system audio are written together.
        mixer.installTap(onBus: 0, bufferSize: 4096, format: tapFormat) { [weak self] buffer, _ in
            guard let self else { return }
            self.writeQueue.async { try? self.audioFile?.write(from: buffer) }
            self.onBuffer?(buffer)
            let level = Self.peakLevel(buffer)
            DispatchQueue.main.async { self.onLevel?(level) }
        }

        try engine.start()
        systemPlayer.play()

        if captureSystem {
            try await startSystemCapture()
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
        engine.mainMixerNode.removeTap(onBus: 0)
        systemPlayer.stop()
        engine.stop()
        audioFile = nil
        state = .finished
        return outputURL
    }

    // MARK: - SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio,
              let pcm = Self.pcmBuffer(from: sampleBuffer) else { return }
        systemPlayer.scheduleBuffer(pcm, completionHandler: nil)
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
