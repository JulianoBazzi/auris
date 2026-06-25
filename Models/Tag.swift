import Foundation
import SwiftData

@Model
final class Tag {
    var id: UUID
    var name: String
    var colorHex: String

    init(id: UUID = UUID(), name: String, colorHex: String = "#3B82F6") {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }
}
