import Foundation
import SwiftData
import WidgetKit

/// Writes the shared `AurisSnapshot` to the app group and reloads widget timelines.
/// App-side only; the widget reads the snapshot through `AurisSnapshot.key`.
enum SharedStore {
    static func load() -> AurisSnapshot {
        guard let data = AppGroup.defaults.data(forKey: AurisSnapshot.key),
              let snapshot = try? JSONDecoder().decode(AurisSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }

    private static func save(_ snapshot: AurisSnapshot) {
        if let data = try? JSONEncoder().encode(snapshot) {
            AppGroup.defaults.set(data, forKey: AurisSnapshot.key)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func setRecording(_ recording: Bool) {
        var snapshot = load()
        snapshot.recording = recording
        save(snapshot)
    }

    @MainActor
    static func updateRecent(from context: ModelContext) {
        var descriptor = FetchDescriptor<Meeting>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = 4
        let meetings = (try? context.fetch(descriptor)) ?? []
        var snapshot = load()
        snapshot.recent = meetings.map {
            MeetingSnapshot(id: $0.id, title: $0.title, colorHex: $0.colorHex,
                            duration: $0.duration, createdAt: $0.createdAt)
        }
        save(snapshot)
    }
}
