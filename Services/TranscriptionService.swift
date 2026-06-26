import Foundation
import AVFoundation
import Speech
import OSLog

private let tlog = Logger(subsystem: "com.bazzi.auris", category: "transcribe")

struct LiveSegment: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var startTime: TimeInterval
    var isFinal: Bool
}

protocol Transcribing: AnyObject {
    func requestAuthorization() async -> Bool
    /// Ensure the on-device speech model for the locale is installed, downloading it if needed.
    /// `progress` reports the download fraction (0...1) on an arbitrary thread.
    func ensureModel(locale: String, progress: @escaping (Double) -> Void) async throws
    /// Begin a streaming on-device recognition session for the given BCP-47 locale.
    func start(locale: String, startOffset: @escaping () -> TimeInterval) async throws
    func append(_ buffer: AVAudioPCMBuffer)
    func stop()
    /// Emits partial (volatile) + final segments as they arrive.
    var onSegment: ((LiveSegment) -> Void)? { get set }
}

/// On-device transcription built on the macOS 26 `SpeechAnalyzer` API. Audio buffers are fed into
/// an `AsyncStream<AnalyzerInput>`; `SpeechTranscriber` streams volatile (partial) and final
/// results continuously — no manual session restart. The locale's recognition model is downloaded
/// on demand via `AssetInventory`.
final class TranscriptionService: NSObject, Transcribing, @unchecked Sendable {
    var onSegment: ((LiveSegment) -> Void)?

    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    private var converter: AVAudioConverter?
    private var analyzerFormat: AVAudioFormat?
    private var offsetProvider: (() -> TimeInterval)?
    private var segmentStart: TimeInterval = 0
    private var appendCount = 0

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
    }

    private static func matches(_ a: Locale, _ b: Locale) -> Bool {
        a.identifier(.bcp47) == b.identifier(.bcp47)
    }

    func ensureModel(locale: String, progress: @escaping (Double) -> Void) async throws {
        let loc = Locale(identifier: locale)

        let supported = await SpeechTranscriber.supportedLocales
        guard supported.contains(where: { Self.matches($0, loc) }) else {
            throw NSError(domain: "Auris.Transcription", code: 2, userInfo: [
                NSLocalizedDescriptionKey: String(localized: "On-device transcription isn't supported for \(locale).")
            ])
        }

        let installed = await SpeechTranscriber.installedLocales
        if installed.contains(where: { Self.matches($0, loc) }) {
            tlog.notice("model already installed locale=\(locale, privacy: .public)")
            return
        }

        // Build a throwaway transcriber to describe the asset we need, then request its install.
        let probe = SpeechTranscriber(locale: loc, preset: .progressiveTranscription)
        guard let request = try await AssetInventory.assetInstallationRequest(supporting: [probe]) else {
            return   // Nothing to install.
        }
        let observation = request.progress.observe(\.fractionCompleted, options: [.initial, .new]) { prog, _ in
            progress(prog.fractionCompleted)
        }
        defer { observation.invalidate() }
        tlog.notice("downloading model locale=\(locale, privacy: .public)")
        try await request.downloadAndInstall()
        progress(1.0)
        tlog.notice("model installed locale=\(locale, privacy: .public)")
    }

    func start(locale: String, startOffset: @escaping () -> TimeInterval) async throws {
        let loc = Locale(identifier: locale)
        let transcriber = SpeechTranscriber(locale: loc, preset: .progressiveTranscription)
        self.transcriber = transcriber

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.analyzer = analyzer
        self.offsetProvider = startOffset
        self.segmentStart = startOffset()
        self.appendCount = 0
        self.analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])

        let (stream, builder) = AsyncStream<AnalyzerInput>.makeStream()
        self.inputBuilder = builder

        resultsTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    tlog.notice("result final=\(result.isFinal) len=\(text.count, privacy: .public) text=\(text, privacy: .private)")
                    self.onSegment?(LiveSegment(text: text, startTime: self.segmentStart, isFinal: result.isFinal))
                    if result.isFinal {
                        self.segmentStart = self.offsetProvider?() ?? self.segmentStart
                    }
                }
            } catch {
                tlog.error("results ended: \(error.localizedDescription, privacy: .public)")
            }
        }

        try await analyzer.start(inputSequence: stream)
        tlog.notice("analyzer started locale=\(locale, privacy: .public) sr=\(self.analyzerFormat?.sampleRate ?? 0)")
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        guard let inputBuilder else { return }
        let out = convert(buffer) ?? buffer
        inputBuilder.yield(AnalyzerInput(buffer: out))
        appendCount += 1
        if appendCount == 1 || appendCount % 100 == 0 {
            tlog.notice("append #\(self.appendCount) ch=\(out.format.channelCount) sr=\(out.format.sampleRate)")
        }
    }

    /// Resamples/reformats an incoming mic/system buffer to the analyzer's required format.
    private func convert(_ input: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let analyzerFormat else { return input }
        if input.format == analyzerFormat { return input }
        if converter == nil || converter?.inputFormat != input.format {
            converter = AVAudioConverter(from: input.format, to: analyzerFormat)
        }
        guard let converter else { return nil }
        let ratio = analyzerFormat.sampleRate / input.format.sampleRate
        let capacity = AVAudioFrameCount(Double(input.frameLength) * ratio) + 1024
        guard let output = AVAudioPCMBuffer(pcmFormat: analyzerFormat, frameCapacity: capacity) else { return nil }
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

    func stop() {
        inputBuilder?.finish()
        inputBuilder = nil
        if let analyzer {
            Task { try? await analyzer.finalizeAndFinishThroughEndOfInput() }
        }
        resultsTask?.cancel()
        resultsTask = nil
        analyzer = nil
        transcriber = nil
        converter = nil
        analyzerFormat = nil
    }
}
