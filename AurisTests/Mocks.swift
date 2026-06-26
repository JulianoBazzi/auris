import Foundation
import AVFoundation
@testable import Auris

/// No-op test doubles for the three injected service protocols. They let `RecordingViewModel`
/// be constructed without touching audio hardware, the Speech framework, or the network.

final class MockAudioCapture: AudioCapturing, @unchecked Sendable {
    var state: CaptureState = .idle
    var onLevel: (@MainActor @Sendable (Float) -> Void)?
    var onBuffer: (@Sendable (AVAudioPCMBuffer) -> Void)?
    var onSystemBuffer: (@Sendable (AVAudioPCMBuffer) -> Void)?
    var onSystemCaptureError: (@Sendable (Error) -> Void)?
    func start(captureMic: Bool, captureSystem: Bool, fileName: String) async throws {}
    func pause() {}
    func resume() {}
    func stop() async -> URL? { nil }
}

final class MockTranscriber: Transcribing, @unchecked Sendable {
    var onSegment: (@Sendable (LiveSegment) -> Void)?
    func requestAuthorization() async -> Bool { true }
    func ensureModel(locale: String, progress: @escaping @Sendable (Double) -> Void) async throws {}
    func start(locale: String, startOffset: @escaping @Sendable () -> TimeInterval) async throws {}
    func append(_ buffer: AVAudioPCMBuffer) {}
    func stop() {}
}

final class MockSummarizer: Summarizing, @unchecked Sendable {
    func summarize(transcript: String, imageData: [Data], language: String) async throws -> MeetingSummary {
        MeetingSummary(executiveSummary: "", topics: [], actionItems: [])
    }
    func suggestMetadata(transcript: String, language: String) async throws -> MeetingSuggestion {
        MeetingSuggestion(title: "", alternativeTitle: "", tags: [], colorHex: "#3B82F6")
    }
}

@MainActor
func makeRecorder() -> RecordingViewModel {
    RecordingViewModel(
        audio: MockAudioCapture(),
        transcriber: MockTranscriber(),
        systemTranscriber: MockTranscriber(),
        summarizer: MockSummarizer()
    )
}
