import SwiftUI
import SwiftData

struct RecordingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Bindable var recorder: RecordingViewModel
    var onFinish: (Meeting?) -> Void

    @State private var title: String = ""
    @State private var showSpeakerSheet = false

    var body: some View {
        VStack(spacing: 0) {
            header
            transcript
            controlBar
        }
        .background(AurisColor.bgPanel)
        .sheet(isPresented: $showSpeakerSheet) {
            SpeakerNamingSheet { name in
                showSpeakerSheet = false
                if let name { recorder.addParticipant(name) }
            }
            .environment(\.locale, appState.localeOverride ?? Locale.current)
        }
        .overlay {
            if recorder.phase == .summarizing { summarizingOverlay }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            TextField("", text: $title, prompt: Text("Untitled meeting"))
                .textFieldStyle(.plain)
                .font(AurisFont.ui(18, .semibold))
                .foregroundStyle(AurisColor.textPrimary)
                .frame(maxWidth: 320)
            Spacer()
            recordingBadge
            Text(recorder.formattedElapsed)
                .font(AurisFont.mono(15, .medium))
                .foregroundStyle(AurisColor.textPrimary)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 28)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AurisColor.borderSubtle).frame(height: 1)
        }
    }

    private var recordingBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(recorder.phase == .paused ? AurisColor.warn : AurisColor.danger)
                .frame(width: 8, height: 8)
            Text(recorder.phase == .paused ? "Paused" : "Recording")
                .font(AurisFont.ui(12, .semibold))
                .foregroundStyle(recorder.phase == .paused ? AurisColor.warn : AurisColor.danger)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .background((recorder.phase == .paused ? AurisColor.warn : AurisColor.danger).opacity(0.12), in: Capsule())
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    if !recorder.participants.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(recorder.participants, id: \.self) { p in
                                Chip(label: p)
                            }
                            Button { showSpeakerSheet = true } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(AurisColor.textSecondary)
                                    .padding(7)
                                    .background(AurisColor.bgElevated, in: Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    ForEach(recorder.segments) { seg in
                        TranscriptRow(
                            speakerName: seg.speakerName,
                            timestamp: seg.timestamp,
                            text: seg.text,
                            accent: Color(hex: seg.speakerColorHex)
                        )
                        .id(seg.id)
                    }
                    if !recorder.liveText.isEmpty {
                        TranscriptRow(
                            speakerName: recorder.participants.first ?? String(localized: "Speaker 1"),
                            timestamp: "…",
                            text: recorder.liveText
                        )
                        .opacity(0.6)
                        .id("live")
                    }
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: recorder.segments.count) {
                withAnimation { proxy.scrollTo(recorder.segments.last?.id, anchor: .bottom) }
            }
        }
    }

    private var controlBar: some View {
        HStack(spacing: 16) {
            Text(recorder.formattedElapsed)
                .font(AurisFont.mono(13))
                .foregroundStyle(AurisColor.textSecondary)
            WaveformView(level: recorder.level)
                .frame(height: 24)
                .frame(maxWidth: .infinity)
            Button { showSpeakerSheet = true } label: {
                controlLabel("person.badge.plus", "Identify speaker")
            }.buttonStyle(.plain)
            Button {
                if recorder.phase == .paused { recorder.resume() } else { recorder.pause() }
            } label: {
                controlLabel(recorder.phase == .paused ? "play.fill" : "pause.fill",
                             recorder.phase == .paused ? "Resume" : "Pause")
            }.buttonStyle(.plain)
            Button { finish() } label: {
                HStack(spacing: 7) {
                    Image(systemName: "stop.fill").font(.system(size: 12))
                    Text("Stop").font(AurisFont.ui(13, .semibold))
                }
                .foregroundStyle(.white)
                .padding(.vertical, 8).padding(.horizontal, 16)
                .background(AurisColor.danger, in: Capsule())
            }.buttonStyle(.plain)
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 28)
        .background(AurisColor.bgSidebar)
        .overlay(alignment: .top) {
            Rectangle().fill(AurisColor.borderSubtle).frame(height: 1)
        }
    }

    private func controlLabel(_ symbol: String, _ key: LocalizedStringKey) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol).font(.system(size: 12))
            Text(key).font(AurisFont.ui(13, .medium))
        }
        .foregroundStyle(AurisColor.textSecondary)
        .padding(.vertical, 8).padding(.horizontal, 14)
        .background(AurisColor.bgElevated, in: Capsule())
        .overlay(Capsule().stroke(AurisColor.border, lineWidth: 1))
    }

    private var summarizingOverlay: some View {
        ZStack {
            AurisColor.bgWindow.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView().controlSize(.large)
                Text("Generating summary…")
                    .font(AurisFont.ui(14, .medium))
                    .foregroundStyle(AurisColor.textPrimary)
            }
            .padding(28)
            .background(AurisColor.bgElevated, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func finish() {
        Task {
            let meeting = await recorder.stopAndSave(
                context: context,
                title: title,
                locale: appState.transcriptionLocale,
                summaryLanguage: appState.summaryLanguage
            )
            onFinish(meeting)
        }
    }
}

/// Simple level-driven waveform of animated bars.
struct WaveformView: View {
    let level: Float
    private let bars = 48

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<bars, id: \.self) { i in
                    let phase = Double(i) / Double(bars)
                    let h = barHeight(phase: phase, max: geo.size.height)
                    Capsule()
                        .fill(LinearGradient.auris)
                        .frame(width: 2.5, height: h)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func barHeight(phase: Double, max: CGFloat) -> CGFloat {
        let wobble = (sin(phase * .pi * 6) + 1) / 2
        let value = CGFloat(level) * (0.4 + 0.6 * wobble)
        return Swift.max(3, value * max)
    }
}
