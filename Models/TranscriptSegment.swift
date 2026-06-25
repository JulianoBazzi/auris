import Foundation
import SwiftData

@Model
final class TranscriptSegment {
    var id: UUID
    /// Seconds from the start of the meeting.
    var startTime: TimeInterval
    var text: String
    var speakerName: String
    var speakerColorHex: String
    var meeting: Meeting?

    init(
        id: UUID = UUID(),
        startTime: TimeInterval,
        text: String,
        speakerName: String,
        speakerColorHex: String = "#60A5FA"
    ) {
        self.id = id
        self.startTime = startTime
        self.text = text
        self.speakerName = speakerName
        self.speakerColorHex = speakerColorHex
    }

    var timestamp: String {
        let total = Int(startTime)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
