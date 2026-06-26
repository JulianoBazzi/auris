import Foundation
import SwiftUI
import SwiftData
import Observation
import AVFoundation

@MainActor
@Observable
final class RecordingViewModel {
    enum Phase: Equatable { case idle, recording, paused, suggesting, summarizing, done }

    var phase: Phase = .idle
    var elapsed: TimeInterval = 0
    var level: Float = 0
    var liveText: String = ""
    var segments: [TranscriptSegment] = []
    var participants: [String] = []
    var pendingImages: [Data] = []
    var errorMessage: String?

    /// Set when the OpenAI summary call fails — drives the "Falha ao gerar resumo" retry card.
    var summaryFailed = false
    /// Set when system-audio (Screen Recording) capture was denied — drives the restart banner.
    var systemCaptureDenied = false
    /// AI metadata suggestion computed after recording stops (drives AISuggestionsSheet).
    var suggestion: MeetingSuggestion?
    /// The meeting persisted when recording stops, awaiting suggestion + summary.
    var pendingMeeting: Meeting?

    var captureMic = true
    var captureSystem = true
    /// Display name used to label the user's own (microphone) speech. Set from settings before start.
    var selfSpeakerName: String = ""

    private let audio: AudioCapturing
    private let transcriber: Transcribing
    private let systemTranscriber: Transcribing
    private let summarizer: Summarizing
    private var timer: Timer?
    private var startDate: Date?
    private var accumulatedBeforePause: TimeInterval = 0
    private var fileName: String?

    init(
        audio: AudioCapturing = AudioCaptureService(),
        transcriber: Transcribing = TranscriptionService(),
        systemTranscriber: Transcribing = TranscriptionService(),
        summarizer: Summarizing = SummarizationService()
    ) {
        self.audio = audio
        self.transcriber = transcriber
        self.systemTranscriber = systemTranscriber
        self.summarizer = summarizer
    }

    var micSpeaker: String {
        selfSpeakerName.isEmpty ? String(localized: "Me") : selfSpeakerName
    }

    var formattedElapsed: String {
        let t = Int(elapsed)
        return String(format: "%02d:%02d:%02d", t / 3600, (t % 3600) / 60, t % 60)
    }

    /// Whether the recording UI should stay on screen (recording, post-stop processing, or a
    /// failed summary awaiting retry).
    var isActive: Bool {
        switch phase {
        case .recording, .paused, .suggesting, .summarizing: return true
        case .idle, .done: return summaryFailed
        }
    }

    func start(locale: String) async {
        // Microphone is the essential source — request it up front.
        if captureMic {
            let micOK = await AVCaptureDevice.requestAccess(for: .audio)
            guard micOK else {
                errorMessage = String(localized: "Microphone access denied. Enable it in System Settings › Privacy.")
                return
            }
        }
        guard await transcriber.requestAuthorization() else {
            errorMessage = String(localized: "Speech recognition not authorized.")
            return
        }
        let name = RecordingStore.newRecordingFileName()
        fileName = name

        audio.onLevel = { [weak self] lvl in self?.level = lvl }
        audio.onBuffer = { [weak self] buf in self?.transcriber.append(buf) }
        audio.onSystemBuffer = { [weak self] buf in self?.systemTranscriber.append(buf) }
        audio.onSystemCaptureError = { [weak self] _ in
            // Non-fatal: keep recording mic-only, but surface the restart banner.
            Task { @MainActor in self?.systemCaptureDenied = true }
        }
        transcriber.onSegment = { [weak self] seg in
            Task { @MainActor in self?.ingestMic(seg) }
        }
        systemTranscriber.onSegment = { [weak self] seg in
            Task { @MainActor in self?.ingestSystem(seg) }
        }

        do {
            try transcriber.start(locale: locale, startOffset: { [weak self] in self?.elapsed ?? 0 })
            // System-audio transcription is best-effort (second recognizer).
            try? systemTranscriber.start(locale: locale, startOffset: { [weak self] in self?.elapsed ?? 0 })
            try await audio.start(captureMic: captureMic, captureSystem: captureSystem, fileName: name)
            startDate = Date()
            accumulatedBeforePause = 0
            errorMessage = nil
            phase = .recording
            startTimer()
            SharedStore.setRecording(true)
        } catch {
            errorMessage = error.localizedDescription
            phase = .idle
        }
    }

    /// Microphone speech → labeled with the user's name; drives the live partial row.
    private func ingestMic(_ seg: LiveSegment) {
        liveText = seg.text
        guard seg.isFinal, !seg.text.isEmpty else { return }
        segments.append(TranscriptSegment(
            startTime: seg.startTime, text: seg.text, speakerName: micSpeaker, speakerColorHex: "#60A5FA"
        ))
        liveText = ""
    }

    /// System audio (remote participants) → labeled "Guest"; final segments only.
    private func ingestSystem(_ seg: LiveSegment) {
        guard seg.isFinal, !seg.text.isEmpty else { return }
        segments.append(TranscriptSegment(
            startTime: seg.startTime, text: seg.text,
            speakerName: String(localized: "Guest"), speakerColorHex: "#B07CF6"
        ))
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

    // MARK: - Stop → persist → suggest → summarize

    /// Stops capture, persists the Meeting (audio + transcript + attachments), then computes an AI
    /// metadata suggestion. The summary itself is generated separately (see `generateSummary`).
    func stopAndPersist(context: ModelContext, title: String, locale: String, summaryLanguage: String) async -> Meeting? {
        timer?.invalidate()
        transcriber.stop()
        systemTranscriber.stop()
        let url = await audio.stop()
        SharedStore.setRecording(false)

        // Give the recognizer a moment to deliver its last final result, then flush any
        // remaining partial so the tail of the conversation isn't lost.
        try? await Task.sleep(nanoseconds: 350_000_000)
        if !liveText.isEmpty {
            segments.append(TranscriptSegment(startTime: elapsed, text: liveText, speakerName: micSpeaker, speakerColorHex: "#60A5FA"))
            liveText = ""
        }
        segments.sort { $0.startTime < $1.startTime }

        let meeting = Meeting(
            title: title.isEmpty ? String(localized: "Untitled meeting") : title,
            duration: elapsed,
            audioFileName: url?.lastPathComponent,
            transcriptionLocale: locale,
            summaryLanguage: summaryLanguage
        )
        for seg in segments { seg.meeting = meeting }
        meeting.segments = segments
        persistAttachments(to: meeting)
        context.insert(meeting)
        try? context.save()   // persist audio + transcript + attachments immediately
        pendingMeeting = meeting

        // Compute the AI suggestion (real call if a key exists, otherwise a local heuristic).
        phase = .suggesting
        let transcript = transcriptText()
        suggestion = try? await summarizer.suggestMetadata(transcript: transcript, language: summaryLanguage)
        return meeting
    }

    /// Applies the user-confirmed suggestion (title, tags, color) to the meeting.
    func applySuggestion(title: String, tags: [String], colorHex: String, to meeting: Meeting, context: ModelContext) {
        if !title.isEmpty { meeting.title = title }
        meeting.colorHex = colorHex
        for name in tags where !name.isEmpty {
            meeting.tags.append(Tag(name: name, colorHex: colorHex))
        }
        try? context.save()
        SharedStore.updateRecent(from: context)
    }

    /// Generates the executive summary for the persisted meeting. Optional: only runs when a key is set.
    func generateSummary(for meeting: Meeting, context: ModelContext, summaryLanguage: String) async {
        summaryFailed = false
        guard KeychainStore.hasKey, !meeting.segments.isEmpty else {
            phase = .done
            SharedStore.updateRecent(from: context)
            return
        }
        phase = .summarizing
        let transcript = meeting.segments
            .sorted { $0.startTime < $1.startTime }
            .map { "\($0.speakerName): \($0.text)" }
            .joined(separator: "\n")
        do {
            let summary = try await summarizer.summarize(
                transcript: transcript, imageData: pendingImages, language: summaryLanguage
            )
            meeting.executiveSummary = summary.executiveSummary
            meeting.topics = summary.topics
            meeting.actionItems = summary.actionItems
            meeting.summaryModel = UserDefaults.standard.string(forKey: "auris.summaryModel") ?? "gpt-4o"
            try? context.save()
        } catch {
            errorMessage = error.localizedDescription
            summaryFailed = true
        }
        phase = .done
        SharedStore.updateRecent(from: context)
    }

    private func transcriptText() -> String {
        segments
            .sorted { $0.startTime < $1.startTime }
            .map { "\($0.speakerName): \($0.text)" }
            .joined(separator: "\n")
    }

    private func persistAttachments(to meeting: Meeting) {
        for data in pendingImages {
            let name = "attach-\(UUID().uuidString).png"
            let url = RecordingStore.attachmentURL(named: name)
            do {
                try data.write(to: url)
                let attachment = Attachment(fileName: name)
                attachment.meeting = meeting
                meeting.attachments.append(attachment)
            } catch {
                // Non-fatal: skip an attachment that fails to write.
            }
        }
    }

    func reset() {
        phase = .idle
        elapsed = 0; level = 0; liveText = ""
        segments = []; participants = []; pendingImages = []
        errorMessage = nil; summaryFailed = false; systemCaptureDenied = false
        suggestion = nil; pendingMeeting = nil
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
