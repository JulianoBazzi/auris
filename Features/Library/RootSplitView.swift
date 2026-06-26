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
    @State private var meetingToDelete: Meeting?

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
                    onSettings: { showSettings = true },
                    onDelete: { meetingToDelete = $0 }
                )
                .frame(width: 262)

                mainArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if appState.showDetailPanel, !showSettings, recorder.phase == .idle, let meeting = selectedMeeting {
                    DetailPanel(meeting: meeting)
                        .frame(width: 300)
                        .transition(.move(edge: .trailing))
                }
            }
        }
        .background(AurisColor.bgWindow)
        .sheet(isPresented: $showConsent) {
            ConsentSheet(playNoticeDefault: appState.playNotice) { proceed in
                showConsent = false
                if proceed {
                    recorder.selfSpeakerName = appState.userDisplayName
                    recorder.transcribeSystem = appState.transcribeSystemAudio
                    Task { await recorder.start(locale: appState.transcriptionLocale) }
                }
            }
            .environment(\.locale, appState.localeOverride ?? Locale.current)
        }
        .onChange(of: appState.selectedMeetingID) { _, newValue in
            if newValue != nil { showSettings = false }
        }
        .sheet(item: $meetingToDelete) { meeting in
            DeleteMeetingSheet(
                meeting: meeting,
                onCancel: { meetingToDelete = nil },
                onConfirm: { delete(meeting) }
            )
            .environment(\.locale, appState.localeOverride ?? Locale.current)
        }
    }

    @ViewBuilder
    private var mainArea: some View {
        if recorder.isActive {
            RecordingView(recorder: recorder, onFinish: { meeting in
                if let meeting { appState.selectedMeetingID = meeting.id }
                recorder.reset()
            })
        } else if showSettings {
            SettingsView(onClose: { showSettings = false })
        } else if let meeting = selectedMeeting {
            SummaryView(meeting: meeting)
        } else if recorder.errorMessage != nil {
            IdleView(recorder: recorder, onStart: { showConsent = true })
        } else if meetings.isEmpty {
            emptyState
        } else {
            IdleView(recorder: recorder, onStart: { showConsent = true })
        }
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            StatusCard(
                icon: "mic.fill",
                title: "No meetings yet",
                message: "Start your first meeting and Auris captures it here with transcript and summary.",
                actionLabel: "Start meeting",
                actionIcon: "record.circle",
                action: { startNewMeeting() }
            )
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AurisColor.bgPanel)
    }

    private func startNewMeeting() {
        appState.selectedMeetingID = nil
        showSettings = false
        recorder.reset()
        showConsent = true
    }

    private func delete(_ meeting: Meeting) {
        if let name = meeting.audioFileName {
            try? FileManager.default.removeItem(at: RecordingStore.recordingURL(named: name))
        }
        for attachment in meeting.attachments {
            try? FileManager.default.removeItem(at: RecordingStore.attachmentURL(named: attachment.fileName))
        }
        if appState.selectedMeetingID == meeting.id { appState.selectedMeetingID = nil }
        context.delete(meeting)
        try? context.save()
        SharedStore.updateRecent(from: context)
        meetingToDelete = nil
    }
}
