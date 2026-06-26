import SwiftUI
import AVFoundation

struct SummaryView: View {
    let meeting: Meeting

    enum Tab { case summary, transcript }
    @State private var tab: Tab = .summary
    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0

    private let ticker = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    private var totalDuration: TimeInterval {
        let d = player?.duration ?? 0
        return d > 0 ? d : meeting.duration
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            audioPlayer
            tabBar
            ScrollView {
                Group {
                    switch tab {
                    case .summary: summaryContent
                    case .transcript: transcriptContent
                    }
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(AurisColor.bgPanel)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Circle().fill(Color(hex: meeting.colorHex)).frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 3) {
                Text(meeting.title)
                    .font(AurisFont.ui(18, .semibold))
                    .foregroundStyle(AurisColor.textPrimary)
                Text("\(meeting.createdAt.formatted(date: .long, time: .shortened)) · \(meeting.formattedDuration)")
                    .font(AurisFont.ui(12))
                    .foregroundStyle(AurisColor.textMuted)
            }
            Spacer()
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 28)
        .overlay(alignment: .bottom) { Rectangle().fill(AurisColor.borderSubtle).frame(height: 1) }
    }

    private var audioPlayer: some View {
        HStack(spacing: 14) {
            Button { togglePlay() } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(LinearGradient.auris, in: Circle())
            }
            .buttonStyle(.plain)
            seekBar
            Text("\(format(currentTime)) / \(format(totalDuration))")
                .font(AurisFont.mono(12))
                .foregroundStyle(AurisColor.textSecondary)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 28)
        .overlay(alignment: .bottom) { Rectangle().fill(AurisColor.borderSubtle).frame(height: 1) }
        .onReceive(ticker) { _ in
            guard let player, isPlaying else { return }
            currentTime = player.currentTime
            if !player.isPlaying { isPlaying = false }
        }
        .onDisappear { player?.stop() }
    }

    /// Waveform doubling as a clickable progress / scrub bar.
    private var seekBar: some View {
        GeometryReader { geo in
            let fraction = totalDuration > 0 ? min(1, max(0, currentTime / totalDuration)) : 0
            ZStack(alignment: .leading) {
                WaveformView(level: isPlaying ? 0.7 : 0.3)
                    .frame(height: 28)
                Rectangle()
                    .fill(AurisColor.accentBright.opacity(0.25))
                    .frame(width: geo.size.width * fraction, height: 28)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onEnded { value in
                    seek(to: value.location.x / geo.size.width)
                }
            )
        }
        .frame(height: 28)
        .frame(maxWidth: .infinity)
    }

    private func seek(to fraction: CGFloat) {
        guard totalDuration > 0 else { return }
        ensurePlayer()
        let time = Double(min(1, max(0, fraction))) * totalDuration
        player?.currentTime = time
        currentTime = time
    }

    private func format(_ t: TimeInterval) -> String {
        let total = Int(t)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private var tabBar: some View {
        HStack(spacing: 8) {
            tabButton("Summary", .summary)
            tabButton("Transcript", .transcript)
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 28)
    }

    private func tabButton(_ key: LocalizedStringKey, _ value: Tab) -> some View {
        Button { tab = value } label: {
            Text(key)
                .font(AurisFont.ui(13, .semibold))
                .foregroundStyle(tab == value ? AurisColor.textPrimary : AurisColor.textMuted)
                .padding(.vertical, 7).padding(.horizontal, 14)
                .background(tab == value ? AurisColor.bgElevated : .clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var summaryContent: some View {
        VStack(alignment: .leading, spacing: 26) {
            block(title: "Executive summary", icon: "doc.text") {
                Text(meeting.executiveSummary ?? "—")
                    .font(AurisFont.ui(14))
                    .foregroundStyle(AurisColor.textSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !meeting.topics.isEmpty {
                block(title: "Key topics", icon: "list.bullet") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(meeting.topics, id: \.self) { bulletRow($0, symbol: "circle.fill") }
                    }
                }
            }
            if !meeting.actionItems.isEmpty {
                block(title: "Action items", icon: "checkmark.circle") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(meeting.actionItems, id: \.self) { bulletRow($0, symbol: "square") }
                    }
                }
            }
        }
    }

    private var transcriptContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(meeting.segments.sorted { $0.startTime < $1.startTime }) { seg in
                TranscriptRow(speakerName: seg.speakerName, timestamp: seg.timestamp,
                              text: seg.text, accent: Color(hex: seg.speakerColorHex))
            }
        }
    }

    private func block<Content: View>(title: LocalizedStringKey, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 13)).foregroundStyle(AurisColor.accentBright)
                Text(title).font(AurisFont.ui(14, .semibold)).foregroundStyle(AurisColor.textPrimary)
            }
            content()
        }
    }

    private func bulletRow(_ text: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: symbol == "square" ? 12 : 6))
                .foregroundStyle(AurisColor.accent)
                .padding(.top, symbol == "square" ? 2 : 6)
            Text(text)
                .font(AurisFont.ui(14))
                .foregroundStyle(AurisColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func togglePlay() {
        if isPlaying { player?.pause(); isPlaying = false; return }
        ensurePlayer()
        player?.play()
        isPlaying = player != nil
    }

    private func ensurePlayer() {
        guard player == nil, let name = meeting.audioFileName else { return }
        player = try? AVAudioPlayer(contentsOf: RecordingStore.recordingURL(named: name))
        player?.prepareToPlay()
    }
}
