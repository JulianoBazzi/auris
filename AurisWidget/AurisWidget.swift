import WidgetKit
import SwiftUI

// MARK: - Snapshot loading (reads the app-group snapshot written by the main app)

enum AurisWidgetStore {
    static func load() -> AurisSnapshot {
        guard let data = AppGroup.defaults.data(forKey: AurisSnapshot.key),
              let snapshot = try? JSONDecoder().decode(AurisSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }
}

struct AurisEntry: TimelineEntry {
    let date: Date
    let snapshot: AurisSnapshot
}

struct AurisProvider: TimelineProvider {
    func placeholder(in context: Context) -> AurisEntry {
        AurisEntry(date: .distantPast, snapshot: .empty)
    }
    func getSnapshot(in context: Context, completion: @escaping (AurisEntry) -> Void) {
        completion(AurisEntry(date: .distantPast, snapshot: AurisWidgetStore.load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<AurisEntry>) -> Void) {
        let entry = AurisEntry(date: .distantPast, snapshot: AurisWidgetStore.load())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

// MARK: - Recent meetings widget (medium)

struct RecentMeetingsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AurisRecentMeetings", provider: AurisProvider()) { entry in
            RecentMeetingsView(snapshot: entry.snapshot)
                .containerBackground(AurisColor.bgWindow, for: .widget)
        }
        .configurationDisplayName("Recent meetings")
        .description("Your latest Auris meetings.")
        .supportedFamilies([.systemMedium])
    }
}

struct RecentMeetingsView: View {
    let snapshot: AurisSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "waveform").font(.system(size: 13)).foregroundStyle(LinearGradient.auris)
                Text("Auris").font(AurisFont.ui(13, .semibold)).foregroundStyle(AurisColor.textPrimary)
                Spacer()
                Text("Recents").font(AurisFont.ui(11)).foregroundStyle(AurisColor.textMuted)
            }
            if snapshot.recent.isEmpty {
                Spacer()
                Text("No meetings yet")
                    .font(AurisFont.ui(12)).foregroundStyle(AurisColor.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                ForEach(snapshot.recent.prefix(3)) { meeting in
                    HStack(spacing: 8) {
                        Circle().fill(Color(hex: meeting.colorHex)).frame(width: 7, height: 7)
                        Text(meeting.title).font(AurisFont.ui(12, .medium))
                            .foregroundStyle(AurisColor.textPrimary).lineLimit(1)
                        Spacer(minLength: 6)
                        Text(meeting.formattedDuration)
                            .font(AurisFont.mono(11)).foregroundStyle(AurisColor.textSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(4)
    }
}

// MARK: - Recording status widget (small)

struct RecordingStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AurisRecordingStatus", provider: AurisProvider()) { entry in
            RecordingStatusView(snapshot: entry.snapshot)
                .containerBackground(AurisColor.bgWindow, for: .widget)
        }
        .configurationDisplayName("Recording status")
        .description("Shows whether Auris is recording.")
        .supportedFamilies([.systemSmall])
    }
}

struct RecordingStatusView: View {
    let snapshot: AurisSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Circle().fill(snapshot.recording ? AurisColor.danger : AurisColor.textMuted)
                    .frame(width: 9, height: 9)
                Text(snapshot.recording ? "Recording" : "Idle")
                    .font(AurisFont.ui(12, .semibold))
                    .foregroundStyle(snapshot.recording ? AurisColor.danger : AurisColor.textSecondary)
            }
            Spacer()
            Image(systemName: snapshot.recording ? "waveform" : "mic.fill")
                .font(.system(size: 34)).foregroundStyle(LinearGradient.auris)
            Spacer()
            Text("Auris").font(AurisFont.ui(12, .semibold)).foregroundStyle(AurisColor.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(4)
    }
}

// MARK: - Bundle

@main
struct AurisWidgetBundle: WidgetBundle {
    var body: some Widget {
        RecentMeetingsWidget()
        RecordingStatusWidget()
    }
}
