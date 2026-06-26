import Foundation
import SwiftUI
import SwiftData
import Observation
import AVFoundation

/// A volatile (in-progress) utterance for one stream, anchored at the time it began.
struct LiveTurn: Identifiable, Equatable {
    let id: String          // stable per stream ("live-mic" / "live-system") for in-place updates
    var startTime: TimeInterval
    var text: String
    var speakerName: String
    var colorHex: String
}

/// One row in the live transcript timeline — a committed segment or a live partial.
struct TimelineItem: Identifiable {
    let id: String
    let startTime: TimeInterval
    let speakerName: String
    let colorHex: String
    let text: String
    let timestamp: String
    let isLive: Bool
}

@MainActor
@Observable
final class RecordingViewModel {
    enum Phase: Equatable { case idle, recording, paused, suggesting, summarizing, done }

    var phase: Phase = .idle
    var elapsed: TimeInterval = 0
    var level: Float = 0
    /// In-progress (volatile) utterance for each stream, shown live in chronological position.
    var liveMic: LiveTurn?
    var liveSystem: LiveTurn?
    var segments: [TranscriptSegment] = []
    var pendingImages: [Data] = []
    var errorMessage: String?

    /// Set when the OpenAI summary call fails — drives the "Falha ao gerar resumo" retry card.
    var summaryFailed = false
    /// True while the detail-screen "Generate summary" action runs (does not touch `phase`).
    var isRegenerating = false
    /// Set when system-audio (Screen Recording) capture was denied — drives the restart banner.
    var systemCaptureDenied = false
    /// True while the on-device speech model for the chosen language is downloading.
    var downloadingModel = false
    /// Download progress (0...1) of the speech model, shown while `downloadingModel` is true.
    var modelDownloadProgress: Double = 0
    /// AI metadata suggestion computed after recording stops (drives AISuggestionsSheet).
    var suggestion: MeetingSuggestion?
    /// The meeting persisted when recording stops, awaiting suggestion + summary.
    var pendingMeeting: Meeting?

    var captureMic = true
    var captureSystem = true
    /// Display name used to label the user's own (microphone) speech. Set from settings before start.
    var selfSpeakerName: String = ""
    /// Localized fallback label for the user (when `selfSpeakerName` is empty) and for the remote
    /// participant. Injected from the view so they follow the app's interface language.
    var meName: String = "Me"
    var guestName: String = "Guest"
    /// Whether to transcribe system audio as a second stream. Set from settings before start.
    var transcribeSystem = true
    /// Set true (e.g. from the menu bar "Stop" button) to ask the recording UI to finish.
    var stopRequested = false

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
        selfSpeakerName.isEmpty ? meName : selfSpeakerName
    }

    /// Committed segments + the live partials, merged in chronological order (a real conversation).
    var timeline: [TimelineItem] {
        var items = segments.map {
            TimelineItem(id: $0.id.uuidString, startTime: $0.startTime, speakerName: $0.speakerName,
                         colorHex: $0.speakerColorHex, text: $0.text, timestamp: $0.timestamp, isLive: false)
        }
        for turn in [liveMic, liveSystem].compactMap({ $0 }) where !turn.text.isEmpty {
            let t = Int(turn.startTime)
            items.append(TimelineItem(id: turn.id, startTime: turn.startTime, speakerName: turn.speakerName,
                                      colorHex: turn.colorHex, text: turn.text,
                                      timestamp: String(format: "%02d:%02d", t / 60, t % 60), isLive: true))
        }
        return items.sorted { $0.startTime < $1.startTime }
    }

    /// Inserts a final segment keeping `segments` ordered by start time, so the live
    /// transcript stays chronological as mic + system finals interleave.
    private func insertSegment(_ seg: TranscriptSegment) {
        let idx = segments.firstIndex { $0.startTime > seg.startTime } ?? segments.count
        segments.insert(seg, at: idx)
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

        // Ensure the on-device model for the chosen language is installed, downloading if needed.
        // Mic and system streams share the locale, so one check covers both.
        do {
            downloadingModel = true
            modelDownloadProgress = 0
            try await transcriber.ensureModel(locale: locale) { [weak self] p in
                Task { @MainActor in self?.modelDownloadProgress = p }
            }
            downloadingModel = false
        } catch {
            downloadingModel = false
            errorMessage = error.localizedDescription
            phase = .idle
            return
        }

        let name = RecordingStore.newRecordingFileName()
        fileName = name

        audio.onLevel = { [weak self] lvl in self?.level = lvl }
        audio.onBuffer = { [weak self] buf in self?.transcriber.append(buf) }
        audio.onSystemCaptureError = { [weak self] _ in
            // Non-fatal: keep recording mic-only, but surface the restart banner.
            Task { @MainActor in self?.systemCaptureDenied = true }
        }
        transcriber.onSegment = { [weak self] seg in
            Task { @MainActor in self?.ingestMic(seg) }
        }
        if transcribeSystem {
            audio.onSystemBuffer = { [weak self] buf in self?.systemTranscriber.append(buf) }
            systemTranscriber.onSegment = { [weak self] seg in
                Task { @MainActor in self?.ingestSystem(seg) }
            }
        }

        do {
            try await transcriber.start(locale: locale, startOffset: { [weak self] in self?.elapsed ?? 0 })
            if transcribeSystem {
                try? await systemTranscriber.start(locale: locale, startOffset: { [weak self] in self?.elapsed ?? 0 })
            }
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

    /// Microphone speech → labeled with the user's name. Live partials show in place; finals commit.
    private func ingestMic(_ seg: LiveSegment) {
        if seg.isFinal {
            if !seg.text.isEmpty {
                insertSegment(TranscriptSegment(
                    startTime: seg.startTime, text: seg.text, speakerName: micSpeaker, speakerColorHex: "#60A5FA"
                ))
            }
            liveMic = nil
        } else {
            liveMic = LiveTurn(id: "live-mic", startTime: seg.startTime, text: seg.text,
                               speakerName: micSpeaker, colorHex: "#60A5FA")
        }
    }

    /// System audio (remote participants) → labeled "Guest". Live partials show in place; finals commit.
    private func ingestSystem(_ seg: LiveSegment) {
        if seg.isFinal {
            if !seg.text.isEmpty {
                insertSegment(TranscriptSegment(
                    startTime: seg.startTime, text: seg.text,
                    speakerName: guestName, speakerColorHex: "#B07CF6"
                ))
            }
            liveSystem = nil
        } else {
            liveSystem = LiveTurn(id: "live-system", startTime: seg.startTime, text: seg.text,
                                  speakerName: guestName, colorHex: "#B07CF6")
        }
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
        if let turn = liveMic, !turn.text.isEmpty {
            insertSegment(TranscriptSegment(startTime: turn.startTime, text: turn.text,
                                            speakerName: micSpeaker, speakerColorHex: "#60A5FA"))
            liveMic = nil
        }
        if let turn = liveSystem, !turn.text.isEmpty {
            insertSegment(TranscriptSegment(startTime: turn.startTime, text: turn.text,
                                            speakerName: guestName, speakerColorHex: "#B07CF6"))
            liveSystem = nil
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

    /// Regenerates the summary for an already-saved meeting (detail screen), without touching `phase`.
    /// Reads attachment images from disk (not `pendingImages`) and uses the meeting's stored language.
    /// Returns `true` on success; on failure sets `errorMessage` and returns `false`.
    @discardableResult
    func regenerateSummary(for meeting: Meeting, context: ModelContext) async -> Bool {
        guard KeychainStore.hasKey, !meeting.segments.isEmpty else {
            errorMessage = SummarizationError.missingKey.localizedDescription
            return false
        }
        isRegenerating = true
        defer { isRegenerating = false }

        let transcript = meeting.segments
            .sorted { $0.startTime < $1.startTime }
            .map { "\($0.speakerName): \($0.text)" }
            .joined(separator: "\n")
        let images = meeting.attachments.compactMap {
            try? Data(contentsOf: RecordingStore.attachmentURL(named: $0.fileName))
        }
        do {
            let summary = try await summarizer.summarize(
                transcript: transcript, imageData: images, language: meeting.summaryLanguage
            )
            meeting.executiveSummary = summary.executiveSummary
            meeting.topics = summary.topics
            meeting.actionItems = summary.actionItems
            meeting.summaryModel = UserDefaults.standard.string(forKey: "auris.summaryModel") ?? "gpt-4o"
            try? context.save()
            SharedStore.updateRecent(from: context)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
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
        elapsed = 0; level = 0; liveMic = nil; liveSystem = nil
        segments = []; pendingImages = []
        errorMessage = nil; summaryFailed = false; systemCaptureDenied = false
        suggestion = nil; pendingMeeting = nil
        stopRequested = false
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
