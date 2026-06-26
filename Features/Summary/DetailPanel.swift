import SwiftUI

/// Right-hand details panel for a meeting. (.pen: Resumo, right column)
struct DetailPanel: View {
    @Environment(AppState.self) private var appState
    let meeting: Meeting

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                aiCard
                section("Participants") {
                    ForEach(participantNames, id: \.self) { name in
                        HStack(spacing: 10) {
                            Circle().fill(AurisColor.accentDim).frame(width: 26, height: 26)
                                .overlay(Text(initials(name)).font(AurisFont.ui(11, .bold)).foregroundStyle(AurisColor.accentBright))
                            Text(name).font(AurisFont.ui(13)).foregroundStyle(AurisColor.textPrimary)
                            Spacer()
                        }
                    }
                }
                if !meeting.attachments.isEmpty {
                    section("Attachments") {
                        Text("\(meeting.attachments.count)")
                            .font(AurisFont.ui(13)).foregroundStyle(AurisColor.textSecondary)
                    }
                }
                section("Tags") {
                    HStack { ForEach(meeting.tags) { Chip(label: $0.name, dotColor: Color(hex: $0.colorHex)) }
                        if meeting.tags.isEmpty {
                            Text("—").font(AurisFont.ui(13)).foregroundStyle(AurisColor.textMuted)
                        }
                    }
                }
            }
            .padding(20)
        }
        .frame(maxHeight: .infinity)
        .background(AurisColor.bgSidebar)
        .overlay(alignment: .leading) { Rectangle().fill(AurisColor.borderSubtle).frame(width: 1) }
    }

    private var participantNames: [String] {
        Array(Set(meeting.segments.map(\.speakerName))).sorted()
    }

    private var aiCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image("Glyph").resizable().scaledToFit().frame(width: 16, height: 16)
                Text(meeting.summaryModel ?? appState.summaryModel).font(AurisFont.ui(13, .semibold)).foregroundStyle(AurisColor.textPrimary)
            }
            Text(meeting.summaryLanguage.uppercased())
                .font(AurisFont.mono(11)).foregroundStyle(AurisColor.textMuted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AurisColor.bgElevated, in: RoundedRectangle(cornerRadius: 12))
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(AurisFont.ui(11, .semibold)).foregroundStyle(AurisColor.textMuted)
            content()
        }
    }

    private func initials(_ name: String) -> String {
        String(name.split(separator: " ").compactMap { $0.first }.prefix(2)).uppercased()
    }
}
