import SwiftUI
import SwiftData

/// Three-pane shell: custom title bar over [sidebar | main | detail panel].
struct RootSplitView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Query(sort: \Meeting.createdAt, order: .reverse) private var meetings: [Meeting]

    @State private var recorder = RecordingViewModel()
    @State private var library = LibraryViewModel()
    @State private var showConsent = false
    @State private var showSettings = false

    private var selectedMeeting: Meeting? {
        meetings.first { $0.id == appState.selectedMeetingID }
    }

    var body: some View {
        @Bindable var appState = appState
        VStack(spacing: 0) {
            TitleBar(showDetailPanel: $appState.showDetailPanel)
            HStack(spacing: 0) {
                SidebarView(
                    meetings: library.filtered(meetings),
                    library: library,
                    onNewMeeting: { startNewMeeting() },
                    onSettings: { showSettings = true }
                )
                .frame(width: 262)

                mainArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if appState.showDetailPanel, recorder.phase == .idle, let meeting = selectedMeeting {
                    DetailPanel(meeting: meeting)
                        .frame(width: 300)
                        .transition(.move(edge: .trailing))
                }
            }
        }
        .background(AurisColor.bgWindow)
        .sheet(isPresented: $showConsent) {
            ConsentSheet { proceed in
                showConsent = false
                if proceed { Task { await recorder.start(locale: appState.transcriptionLocale) } }
            }
            .environment(\.locale, appState.localeOverride ?? Locale.current)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(appState)
                .environment(\.locale, appState.localeOverride ?? Locale.current)
        }
    }

    @ViewBuilder
    private var mainArea: some View {
        switch recorder.phase {
        case .recording, .paused, .summarizing:
            RecordingView(recorder: recorder, onFinish: { meeting in
                if let meeting { appState.selectedMeetingID = meeting.id }
                recorder.reset()
            })
        default:
            if let meeting = selectedMeeting {
                SummaryView(meeting: meeting)
            } else {
                IdleView(
                    recorder: recorder,
                    onStart: { showConsent = true }
                )
            }
        }
    }

    private func startNewMeeting() {
        appState.selectedMeetingID = nil
        recorder.reset()
        showConsent = true
    }
}
