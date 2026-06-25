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

    /// Seeds a few example meetings the first time the library is empty (mock content matching the design).
    static func seedIfNeeded(_ context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Meeting>())) ?? 0
        guard count == 0 else { return }

        let samples: [(String, String, [String], [String], Double)] = [
            ("Product sync", "#3B82F6",
             ["Onboarding before launch", "API stabilization", "Documentation gaps"],
             ["Wireframe the new onboarding", "Finalize API docs"], 1920),
            ("1:1 with Marina", "#B07CF6",
             ["Roadmap priorities", "Hiring plan"],
             ["Send role description"], 1500),
            ("Discovery — client", "#34D399",
             ["Requirements", "Budget", "Timeline"],
             ["Draft proposal"], 2640)
        ]

        for (i, s) in samples.enumerated() {
            let meeting = Meeting(
                title: s.0,
                createdAt: Date().addingTimeInterval(Double(-i) * 86_400),
                duration: s.4,
                summaryLanguage: "en",
                executiveSummary: "Auto-generated example summary for \"\(s.0)\". Replace by recording a real meeting.",
                topics: s.2,
                actionItems: s.3,
                colorHex: s.1
            )
            let speakers = ["Ana Silva", "Bruno Costa"]
            meeting.segments = [
                TranscriptSegment(startTime: 12, text: "I think we should prioritize onboarding before launch.", speakerName: speakers[0], speakerColorHex: "#60A5FA"),
                TranscriptSegment(startTime: 31, text: "Agreed. The API still needs to stabilize first.", speakerName: speakers[1], speakerColorHex: "#B07CF6")
            ]
            meeting.segments.forEach { $0.meeting = meeting }
            context.insert(meeting)
        }
        try? context.save()
    }
}
