import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class LibraryViewModel {
    var searchText: String = ""
    var selectedTagName: String?

    func filtered(_ meetings: [Meeting]) -> [Meeting] {
        meetings.filter { m in
            (searchText.isEmpty || m.title.localizedCaseInsensitiveContains(searchText)) &&
            (selectedTagName == nil || m.tags.contains { $0.name == selectedTagName })
        }
    }

    /// Removes the example/mock meetings that earlier builds seeded (identified by the marker text
    /// in their executive summary). Real recordings are untouched.
    static func removeSeedData(_ context: ModelContext) {
        let meetings = (try? context.fetch(FetchDescriptor<Meeting>())) ?? []
        var removed = false
        for meeting in meetings where (meeting.executiveSummary ?? "").hasPrefix("Auto-generated example summary") {
            context.delete(meeting)
            removed = true
        }
        if removed { try? context.save() }
    }
}
