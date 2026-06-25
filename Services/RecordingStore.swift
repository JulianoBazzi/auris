import Foundation

/// Resolves on-disk locations for recordings and attachments under Application Support.
enum RecordingStore {
    static var baseDirectory: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("Auris", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var recordingsDirectory: URL {
        let dir = baseDirectory.appendingPathComponent("recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var attachmentsDirectory: URL {
        let dir = baseDirectory.appendingPathComponent("attachments", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func recordingURL(named name: String) -> URL {
        recordingsDirectory.appendingPathComponent(name)
    }

    static func attachmentURL(named name: String) -> URL {
        attachmentsDirectory.appendingPathComponent(name)
    }

    static func newRecordingFileName() -> String {
        "meeting-\(UUID().uuidString).m4a"
    }
}
