import Testing
import Foundation
@testable import Auris

/// Pure, deterministic logic — no I/O, no system frameworks.
struct PureLogicTests {

    // MARK: LibraryViewModel.filtered

    @Test @MainActor func filterMatchesTitleCaseInsensitively() {
        let vm = LibraryViewModel()
        let meetings = [Meeting(title: "Standup"), Meeting(title: "Retrospective")]

        vm.searchText = "stand"
        #expect(vm.filtered(meetings).map(\.title) == ["Standup"])

        vm.searchText = "STAND"
        #expect(vm.filtered(meetings).map(\.title) == ["Standup"])
    }

    @Test @MainActor func emptySearchReturnsEverything() {
        let vm = LibraryViewModel()
        let meetings = [Meeting(title: "A"), Meeting(title: "B")]
        vm.searchText = ""
        #expect(vm.filtered(meetings).count == 2)
    }

    @Test @MainActor func filterByTagName() {
        let vm = LibraryViewModel()
        let tagged = Meeting(title: "Planning")
        tagged.tags = [Tag(name: "work", colorHex: "#3B82F6")]
        let untagged = Meeting(title: "Coffee")

        vm.selectedTagName = "work"
        #expect(vm.filtered([tagged, untagged]).map(\.title) == ["Planning"])
    }

    // MARK: Duration / timestamp formatting

    @Test func meetingFormattedDuration() {
        #expect(Meeting(title: "x", duration: 65).formattedDuration == "01:05")
        #expect(Meeting(title: "x", duration: 3661).formattedDuration == "1:01:01")
        #expect(Meeting(title: "x", duration: 0).formattedDuration == "00:00")
    }

    @Test func transcriptSegmentTimestamp() {
        #expect(TranscriptSegment(startTime: 75, text: "hi", speakerName: "S").timestamp == "01:15")
        #expect(TranscriptSegment(startTime: 5, text: "hi", speakerName: "S").timestamp == "00:05")
    }

    @Test func meetingSnapshotFormattedDuration() {
        let snap = MeetingSnapshot(id: UUID(), title: "x", colorHex: "#fff", duration: 3661, createdAt: Date())
        #expect(snap.formattedDuration == "1:01:01")
    }

    @Test func snapshotCodableRoundTrip() throws {
        let original = AurisSnapshot(
            recording: true,
            recent: [MeetingSnapshot(id: UUID(), title: "Standup", colorHex: "#3B82F6",
                                     duration: 90, createdAt: Date(timeIntervalSince1970: 1_000))]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AurisSnapshot.self, from: data)

        #expect(decoded.recording == true)
        #expect(decoded.recent.count == 1)
        #expect(decoded.recent.first?.id == original.recent.first?.id)
        #expect(decoded.recent.first?.title == "Standup")
        #expect(decoded.recent.first?.duration == 90)
    }

    // MARK: UsageStore cost estimate

    @Test func usageCostEstimate() {
        UsageStore.reset()
        defer { UsageStore.reset() }

        UsageStore.record(tokens: 2000)
        #expect(UsageStore.tokenCount == 2000)
        #expect(UsageStore.summaryCount == 1)
        // 2000 tokens / 1000 * $0.005 = $0.01
        #expect(abs(UsageStore.estimatedCostUSD - 0.01) < 1e-9)

        // Negative token counts are clamped to zero.
        UsageStore.record(tokens: -50)
        #expect(UsageStore.tokenCount == 2000)
        #expect(UsageStore.summaryCount == 2)
    }
}
