import Foundation
import SwiftData

@Model
final class Attachment {
    var id: UUID
    /// Relative path of the image inside the attachments directory.
    var fileName: String
    var addedAt: Date
    var meeting: Meeting?

    init(id: UUID = UUID(), fileName: String, addedAt: Date = Date()) {
        self.id = id
        self.fileName = fileName
        self.addedAt = addedAt
    }
}
