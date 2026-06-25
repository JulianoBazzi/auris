import Foundation
import SwiftData

@Model
final class Meeting {
    var id: UUID
    var title: String
    var createdAt: Date
    /// Duration in seconds.
    var duration: TimeInterval
    /// Relative path of the audio file inside the recordings directory.
    var audioFileName: String?
    /// BCP-47 locale used for transcription (e.g. "pt-BR").
    var transcriptionLocale: String
    /// Language the summary was generated in (e.g. "pt-BR").
    var summaryLanguage: String
    var executiveSummary: String?
    var topics: [String]
    var actionItems: [String]
    /// Hex color used for the sidebar dot / tag accent.
    var colorHex: String

    @Relationship(deleteRule: .cascade, inverse: \TranscriptSegment.meeting)
    var segments: [TranscriptSegment]
    @Relationship(deleteRule: .cascade, inverse: \Speaker.meeting)
    var speakers: [Speaker]
    @Relationship(deleteRule: .cascade, inverse: \Attachment.meeting)
    var attachments: [Attachment]
    @Relationship(deleteRule: .nullify)
    var tags: [Tag]

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        duration: TimeInterval = 0,
        audioFileName: String? = nil,
        transcriptionLocale: String = "en-US",
        summaryLanguage: String = "en",
        executiveSummary: String? = nil,
        topics: [String] = [],
        actionItems: [String] = [],
        colorHex: String = "#3B82F6"
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.duration = duration
        self.audioFileName = audioFileName
        self.transcriptionLocale = transcriptionLocale
        self.summaryLanguage = summaryLanguage
        self.executiveSummary = executiveSummary
        self.topics = topics
        self.actionItems = actionItems
        self.colorHex = colorHex
        self.segments = []
        self.speakers = []
        self.attachments = []
        self.tags = []
    }

    var formattedDuration: String {
        let total = Int(duration)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s)
                     : String(format: "%02d:%02d", m, s)
    }
}
