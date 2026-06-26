import Foundation

/// Lightweight, Codable snapshot of app state shared with the WidgetKit extension via the app group.
/// This file is compiled into BOTH the app and the widget target.
struct MeetingSnapshot: Codable, Identifiable {
    var id: UUID
    var title: String
    var colorHex: String
    var duration: TimeInterval
    var createdAt: Date

    var formattedDuration: String {
        let total = Int(duration)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s)
                     : String(format: "%02d:%02d", m, s)
    }
}

struct AurisSnapshot: Codable {
    var recording: Bool = false
    var recent: [MeetingSnapshot] = []

    static let key = "auris.snapshot"
    static let empty = AurisSnapshot()
}
