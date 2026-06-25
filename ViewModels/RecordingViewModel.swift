import Foundation
import SwiftUI
import SwiftData
import Observation

@MainActor
@Observable
final class RecordingViewModel {
    enum Phase: Equatable { case idle, recording, paused, summarizing, done }

    var phase: Phase = .idle
    var elapsed: TimeInterval = 0
    var level: Float = 0
    var liveText: String = ""
    var segments: [TranscriptSegment] = []
    var participants: [String] = []
    var pendingImages: [Data] = []
    var errorMessage: String?

    var captureMic = true
    var captureSystem = true

    private let audio: AudioCapturing
    private let transcriber: Transcribing
    private let summarizer: Summarizing
    private var timer: Timer?
    private var startDate: Date?
    private var accumulatedBeforePause: TimeInterval = 0
    private var fileName: String?

    init(
        audio: AudioCapturing = AudioCaptureService(),
        transcriber: Transcribing = TranscriptionService(),
        summarizer: Summarizing = SummarizationService()
    ) {
        self.audio = audio
        self.transcriber = transcriber
        self.summarizer = summarizer
    }

    var formattedElapsed: String {
        let t = Int(elapsed)
        return String(format: "%02d:%02d:%02d", t / 3600, (t % 3600) / 60, t % 60)
    }

    func start(locale: String) async {
        guard await transcriber.requestAuthorization() else {
            errorMessage = "Speech recognition not authorized."
            return
        }
        let name = RecordingStore.newRecordingFileName()
        fileName = name

        audio.onLevel = { [weak self] lvl in self?.level = lvl }
        audio.onBuffer = { [weak self] buf in self?.transcriber.append(buf) }
        transcriber.onSegment = { [weak self] seg in
            Task { @MainActor in self?.ingest(seg) }
        }

        do {
            try transcriber.start(locale: locale, startOffset: { [weak self] in self?.elapsed ?? 0 })
            try await audio.start(captureMic: captureMic, captureSystem: captureSystem, fileName: name)
            startDate = Date()
            accumulatedBeforePause = 0
            phase = .recording
            startTimer()
        } catch {
            errorMessage = error.localizedDescription
            phase = .idle
        }
    }

    private func ingest(_ seg: LiveSegment) {
        liveText = seg.text
        guard seg.isFinal, !seg.text.isEmpty else { return }
        let speaker = participants.first ?? String(localized: "Speaker 1")
        let segment = TranscriptSegment(
            startTime: seg.startTime, text: seg.text, speakerName: speaker
        )
        segments.append(segment)
        liveText = ""
    }

    func pause() {
        audio.pause()
        accumulatedBeforePause = elapsed
        startDate = nil
        timer?.invalidate()
        phase = .paused
    }

    func resume() {
        audio.resume()
        startDate = Date()
        startTimer()
        phase = .recording
    }

    func attach(_ data: Data) { pendingImages.append(data) }

    func addParticipant(_ name: String) {
        if !name.isEmpty, !participants.contains(name) { participants.append(name) }
    }

    /// Stops capture, persists the Meeting, then requests a summary.
    func stopAndSave(context: ModelContext, title: String, locale: String, summaryLanguage: String) async -> Meeting? {
        timer?.invalidate()
        transcriber.stop()
        let url = await audio.stop()
        phase = .summarizing

        let meeting = Meeting(
            title: title.isEmpty ? String(localized: "Untitled meeting") : title,
            duration: elapsed,
            audioFileName: url?.lastPathComponent,
            transcriptionLocale: locale,
            summaryLanguage: summaryLanguage
        )
        for seg in segments { seg.meeting = meeting }
        meeting.segments = segments
        context.insert(meeting)

        let transcript = segments.map { "\($0.speakerName): \($0.text)" }.joined(separator: "\n")
        do {
            let summary = try await summarizer.summarize(
                transcript: transcript, imageData: pendingImages, language: summaryLanguage
            )
            meeting.executiveSummary = summary.executiveSummary
            meeting.topics = summary.topics
            meeting.actionItems = summary.actionItems
        } catch {
            errorMessage = error.localizedDescription
        }

        try? context.save()
        phase = .done
        return meeting
    }

    func reset() {
        phase = .idle
        elapsed = 0; level = 0; liveText = ""
        segments = []; participants = []; pendingImages = []
        errorMessage = nil
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let start = self.startDate else { return }
                self.elapsed = self.accumulatedBeforePause + Date().timeIntervalSince(start)
            }
        }
    }
}
