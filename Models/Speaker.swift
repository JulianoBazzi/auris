import Foundation
import SwiftData

@Model
final class Speaker {
    var id: UUID
    var name: String
    var colorHex: String
    /// Reuse this label automatically in future meetings.
    var rememberVoice: Bool
    var meeting: Meeting?

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = "#60A5FA",
        rememberVoice: Bool = false
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.rememberVoice = rememberVoice
    }
}
