import Foundation
import AVFoundation
import Speech

struct LiveSegment: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var startTime: TimeInterval
    var isFinal: Bool
}

protocol Transcribing: AnyObject {
    func requestAuthorization() async -> Bool
    /// Begin a streaming on-device recognition session for the given BCP-47 locale.
    func start(locale: String, startOffset: @escaping () -> TimeInterval) throws
    func append(_ buffer: AVAudioPCMBuffer)
    func stop()
    /// Emits partial + final segments as they arrive.
    var onSegment: ((LiveSegment) -> Void)? { get set }
}

final class TranscriptionService: NSObject, Transcribing, @unchecked Sendable {
    var onSegment: ((LiveSegment) -> Void)?

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var offsetProvider: (() -> TimeInterval)?
    private var segmentStart: TimeInterval = 0
    private var isStopping = false
    private var isRestarting = false
    /// True once on-device recognition has failed without producing a result, so we retry on the
    /// server (works even when the locale's offline model isn't installed).
    private var forceServer = false
    /// Whether the current session has yielded at least one result.
    private var gotResult = false
    /// Serializes restart so it never re-enters on the Speech callback thread (which would block
    /// on synchronous XPC inside `SFSpeechRecognizer`).
    private let controlQueue = DispatchQueue(label: "com.bazzi.auris.transcribe")

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
    }

    func start(locale: String, startOffset: @escaping () -> TimeInterval) throws {
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale))
        guard let recognizer, recognizer.isAvailable else {
            throw NSError(domain: "Auris.Transcription", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Recognizer unavailable for \(locale)"])
        }
        self.recognizer = recognizer
        self.offsetProvider = startOffset
        self.segmentStart = startOffset()
        self.isStopping = false
        self.gotResult = false

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Prefer on-device, but fall back to server recognition if the offline model isn't available.
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition && !forceServer
        self.request = request

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                self.gotResult = true
                let text = result.bestTranscription.formattedString
                self.onSegment?(LiveSegment(text: text, startTime: self.segmentStart, isFinal: result.isFinal))
                if result.isFinal {
                    self.segmentStart = self.offsetProvider?() ?? self.segmentStart
                }
            }
            if error != nil, !self.isStopping {
                // On-device failed before yielding anything → retry via the server next time.
                if !self.gotResult, !self.forceServer { self.forceServer = true }
                self.restart(locale: locale)
            }
        }
    }

    private func restart(locale: String) {
        controlQueue.async { [weak self] in
            guard let self, !self.isStopping, !self.isRestarting,
                  let provider = self.offsetProvider else { return }
            self.isRestarting = true
            self.request?.endAudio()
            self.task?.cancel()
            self.task = nil
            try? self.start(locale: locale, startOffset: provider)
            self.isRestarting = false
        }
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        request?.append(buffer)
    }

    func stop() {
        isStopping = true
        forceServer = false
        request?.endAudio()
        task?.finish()
        task = nil
        request = nil
    }
}
