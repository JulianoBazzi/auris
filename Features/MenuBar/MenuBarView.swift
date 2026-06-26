import SwiftUI
import SwiftData

/// Menu-bar popover: quick status + start/open shortcuts. (.pen roadmap: menu-bar indicator)
struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \Meeting.createdAt, order: .reverse) private var meetings: [Meeting]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image("Glyph").resizable().scaledToFit().frame(width: 18, height: 18)
                Text("Auris").font(AurisFont.ui(14, .semibold)).foregroundStyle(AurisColor.textPrimary)
                Spacer()
                HStack(spacing: 6) {
                    Circle().fill(appState.hasOpenAIKey ? AurisColor.success : AurisColor.textMuted)
                        .frame(width: 7, height: 7)
                    Text(appState.hasOpenAIKey ? "\(appState.summaryModel) connected" : "Not connected")
                        .font(AurisFont.ui(11)).foregroundStyle(AurisColor.textSecondary)
                }
            }

            Button {
                appState.selectedMeetingID = nil
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "record.circle").font(.system(size: 13))
                    Text("New meeting")
                    Spacer()
                }
            }
            .buttonStyle(GradientButtonStyle(verticalPadding: 9))

            if !meetings.isEmpty {
                Divider().overlay(AurisColor.borderSubtle)
                ForEach(meetings.prefix(4)) { meeting in
                    Button {
                        appState.selectedMeetingID = meeting.id
                        NSApp.activate(ignoringOtherApps: true)
                    } label: {
                        HStack(spacing: 8) {
                            Circle().fill(Color(hex: meeting.colorHex)).frame(width: 7, height: 7)
                            Text(meeting.title).font(AurisFont.ui(12)).foregroundStyle(AurisColor.textPrimary)
                            Spacer()
                            Text(meeting.formattedDuration).font(AurisFont.mono(11)).foregroundStyle(AurisColor.textMuted)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider().overlay(AurisColor.borderSubtle)
            Button { NSApp.terminate(nil) } label: {
                Text("Quit Auris").font(AurisFont.ui(12)).foregroundStyle(AurisColor.textSecondary)
            }.buttonStyle(.plain)
        }
        .padding(16)
        .frame(width: 280)
        .background(AurisColor.bgElevated)
        .preferredColorScheme(.dark)
    }
}
