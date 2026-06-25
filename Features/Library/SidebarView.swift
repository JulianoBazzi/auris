import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    let meetings: [Meeting]
    @Bindable var library: LibraryViewModel
    var onNewMeeting: () -> Void
    var onSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                Button(action: onNewMeeting) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                        Text("New meeting")
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(GradientButtonStyle(verticalPadding: 10))

                searchField

                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(meetings) { meeting in
                            Button {
                                appState.selectedMeetingID = meeting.id
                            } label: {
                                SidebarItem(
                                    title: meeting.title,
                                    meta: "\(meeting.createdAt.formatted(date: .abbreviated, time: .omitted)) · \(meeting.formattedDuration)",
                                    dotColor: Color(hex: meeting.colorHex),
                                    isSelected: appState.selectedMeetingID == meeting.id
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(14)

            Spacer(minLength: 0)
            footer
        }
        .frame(maxHeight: .infinity)
        .background(AurisColor.bgSidebar)
        .overlay(alignment: .trailing) {
            Rectangle().fill(AurisColor.borderSubtle).frame(width: 1)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(AurisColor.textMuted)
            TextField("", text: $library.searchText, prompt: Text("Search"))
                .textFieldStyle(.plain)
                .font(AurisFont.ui(13))
                .foregroundStyle(AurisColor.textPrimary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 11)
        .background(AurisColor.bgPanel, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(AurisColor.border, lineWidth: 1))
    }

    private var footer: some View {
        Button(action: onSettings) {
            HStack(spacing: 10) {
                Circle()
                    .fill(appState.hasOpenAIKey ? AurisColor.success : AurisColor.textMuted)
                    .frame(width: 8, height: 8)
                Text(appState.hasOpenAIKey ? "GPT-4o connected" : "Not connected")
                    .font(AurisFont.ui(12, .medium))
                    .foregroundStyle(AurisColor.textSecondary)
                Spacer(minLength: 0)
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundStyle(AurisColor.textMuted)
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            Rectangle().fill(AurisColor.borderSubtle).frame(height: 1)
        }
    }
}
