import Testing
import Foundation
@testable import Auris

/// The local fallback used when no OpenAI key is set — must always produce a suggestion.
struct SummarizationHeuristicTests {

    @Test func titleFromFirstSixWords() {
        let s = SummarizationService.heuristicSuggestion(
            transcript: "Alice: Let's discuss the quarterly budget plan today"
        )
        #expect(s.title == "Alice Let's discuss the quarterly budget")
        #expect(s.tags.isEmpty)
        #expect(s.alternativeTitle.isEmpty)
        #expect(s.colorHex == "#3B82F6")
    }

    @Test func usesOnlyFirstLine() {
        let s = SummarizationService.heuristicSuggestion(transcript: "Kickoff meeting\nsecond line here")
        #expect(s.title == "Kickoff meeting")
    }

    @Test func emptyTranscriptGivesEmptyTitle() {
        let s = SummarizationService.heuristicSuggestion(transcript: "")
        #expect(s.title.isEmpty)
        #expect(s.colorHex == "#3B82F6")
    }
}
