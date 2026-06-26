import Testing
import Foundation
@testable import Auris

/// Pure view-model surface, exercised with mock services injected (see Mocks.swift).
@MainActor
struct RecordingViewModelTests {

    @Test func micSpeakerFallsBackToMeName() {
        let vm = makeRecorder()
        vm.meName = "Eu"
        vm.selfSpeakerName = ""
        #expect(vm.micSpeaker == "Eu")

        vm.selfSpeakerName = "Bob"
        #expect(vm.micSpeaker == "Bob")
    }

    @Test func isActiveAcrossPhases() {
        let vm = makeRecorder()

        vm.phase = .recording
        #expect(vm.isActive)

        vm.phase = .suggesting
        #expect(vm.isActive)

        vm.phase = .idle
        vm.summaryFailed = false
        #expect(!vm.isActive)

        vm.phase = .done
        vm.summaryFailed = true
        #expect(vm.isActive)
    }

    @Test func formattedElapsed() {
        let vm = makeRecorder()
        vm.elapsed = 3661
        #expect(vm.formattedElapsed == "01:01:01")
    }

    @Test func timelineMergesAndSortsLivePartials() {
        let vm = makeRecorder()
        vm.segments = [
            TranscriptSegment(startTime: 10, text: "later", speakerName: "S"),
            TranscriptSegment(startTime: 5, text: "earlier", speakerName: "S")
        ]
        vm.liveMic = LiveTurn(id: "live-mic", startTime: 2, text: "live", speakerName: "Me", colorHex: "#60A5FA")
        // Empty live text must be excluded from the timeline.
        vm.liveSystem = LiveTurn(id: "live-system", startTime: 99, text: "", speakerName: "Guest", colorHex: "#B07CF6")

        let times = vm.timeline.map(\.startTime)
        #expect(times == [2, 5, 10])
        #expect(vm.timeline.first?.isLive == true)
        #expect(vm.timeline.allSatisfy { $0.startTime != 99 })
    }

    @Test func resetClearsState() {
        let vm = makeRecorder()
        vm.elapsed = 42
        vm.segments = [TranscriptSegment(startTime: 1, text: "x", speakerName: "S")]
        vm.summaryFailed = true
        vm.phase = .done

        vm.reset()

        #expect(vm.elapsed == 0)
        #expect(vm.segments.isEmpty)
        #expect(!vm.summaryFailed)
        #expect(vm.phase == .idle)
    }

    // NOTE: stopAndPersist / applySuggestion are intentionally not unit-tested. They
    // require a SwiftData ModelContext, and instantiating a second ModelContainer inside
    // this app-hosted test bundle SIGTRAPs (the host app's @main already owns one for the
    // same schema). applySuggestion additionally mutates a to-many relationship and calls
    // SharedStore.updateRecent (WidgetKit). See the plan's "Known untestable seams".

    // MARK: pause / resume / attach

    @Test func pauseAndResumeTransitionPhases() {
        let vm = makeRecorder()
        vm.phase = .recording
        vm.elapsed = 5
        vm.pause()
        #expect(vm.phase == .paused)
        vm.resume()
        #expect(vm.phase == .recording)
    }

    @Test func attachAppendsPendingImage() {
        let vm = makeRecorder()
        vm.attach(Data([1, 2, 3]))
        #expect(vm.pendingImages.count == 1)
    }
}
