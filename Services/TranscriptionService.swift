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

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                self.onSegment?(LiveSegment(text: text, startTime: self.segmentStart, isFinal: result.isFinal))
                if result.isFinal {
                    self.segmentStart = self.offsetProvider?() ?? self.segmentStart
                }
            }
            if error != nil { self.restart(locale: locale) }
        }
    }

    private func restart(locale: String) {
        guard let provider = offsetProvider else { return }
        request?.endAudio()
        task = nil
        try? start(locale: locale, startOffset: provider)
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        request?.append(buffer)
    }

    func stop() {
        request?.endAudio()
        task?.finish()
        task = nil
        request = nil
    }
}
