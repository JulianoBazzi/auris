import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit

struct RecordingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Bindable var recorder: RecordingViewModel
    var onFinish: (Meeting?) -> Void

    @State private var title: String = ""
    @State private var showSpeakerSheet = false
    @State private var showImporter = false

    var body: some View {
        VStack(spacing: 0) {
            header
            if recorder.systemCaptureDenied { systemDeniedBanner }
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
        .sheet(isPresented: suggestionBinding) {
            if let suggestion = recorder.suggestion, let meeting = recorder.pendingMeeting {
                AISuggestionsSheet(
                    suggestion: suggestion,
                    onApply: { t, tags, color in
                        recorder.applySuggestion(title: t, tags: tags, colorHex: color, to: meeting, context: context)
                        runSummary(meeting)
                    },
                    onDiscard: { runSummary(meeting) }
                )
                .environment(\.locale, appState.localeOverride ?? Locale.current)
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                for url in urls { importImage(url) }
            }
        }
        .overlay {
            if recorder.phase == .summarizing { summarizingOverlay }
            else if recorder.summaryFailed { summaryFailedOverlay }
        }
    }

    /// Present the suggestions sheet while phase is `.suggesting` and a suggestion exists.
    private var suggestionBinding: Binding<Bool> {
        Binding(
            get: { recorder.phase == .suggesting && recorder.suggestion != nil && recorder.pendingMeeting != nil },
            set: { _ in }
        )
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

    private var systemDeniedBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.dashed.badge.record")
                .font(.system(size: 15)).foregroundStyle(AurisColor.warn)
            VStack(alignment: .leading, spacing: 2) {
                Text("System audio blocked")
                    .font(AurisFont.ui(13, .semibold)).foregroundStyle(AurisColor.textPrimary)
                Text("Grant Screen Recording, then restart Auris to capture system audio. Recording continues with the microphone only.")
                    .font(AurisFont.ui(11)).foregroundStyle(AurisColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button { AppRelaunch.openScreenRecordingSettings() } label: {
                Text("Open Settings")
                    .font(AurisFont.ui(12, .medium)).foregroundStyle(AurisColor.textSecondary)
                    .padding(.vertical, 6).padding(.horizontal, 12)
                    .overlay(Capsule().stroke(AurisColor.border, lineWidth: 1))
            }.buttonStyle(.plain)
            Button { AppRelaunch.restart() } label: {
                Text("Restart")
            }.buttonStyle(GradientButtonStyle(horizontalPadding: 14, verticalPadding: 6, fontSize: 12))
            Button { recorder.systemCaptureDenied = false } label: {
                Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AurisColor.textMuted)
            }.buttonStyle(.plain)
        }
        .padding(.vertical, 10).padding(.horizontal, 28)
        .background(AurisColor.warn.opacity(0.10))
        .overlay(alignment: .bottom) { Rectangle().fill(AurisColor.borderSubtle).frame(height: 1) }
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
                            speakerName: recorder.micSpeaker,
                            timestamp: "…",
                            text: recorder.liveText
                        )
                        .opacity(0.6)
                        .id("live")
                    }
                    if !recorder.pendingImages.isEmpty { attachmentStrip }
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: recorder.segments.count) {
                withAnimation { proxy.scrollTo(recorder.segments.last?.id, anchor: .bottom) }
            }
        }
    }

    private var attachmentStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Attachments").font(AurisFont.ui(11, .semibold)).foregroundStyle(AurisColor.textMuted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(recorder.pendingImages.enumerated()), id: \.offset) { _, data in
                        if let img = NSImage(data: data) {
                            Image(nsImage: img)
                                .resizable().scaledToFill()
                                .frame(width: 140, height: 88)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AurisColor.border, lineWidth: 1))
                        }
                    }
                }
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
            Button { showImporter = true } label: {
                controlLabel("paperclip", "Attach")
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
        processingCard(
            title: "Generating summary…",
            subtitle: "Auris is turning the transcript into an executive summary."
        )
    }

    private func processingCard(title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        ZStack {
            AurisColor.bgWindow.opacity(0.78).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView().controlSize(.large)
                Text(title)
                    .font(AurisFont.ui(15, .semibold))
                    .foregroundStyle(AurisColor.textPrimary)
                Text(subtitle)
                    .font(AurisFont.ui(12))
                    .foregroundStyle(AurisColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
            .padding(30)
            .background(AurisColor.bgElevated, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AurisColor.border, lineWidth: 1))
        }
    }

    private var summaryFailedOverlay: some View {
        ZStack {
            AurisColor.bgWindow.opacity(0.78).ignoresSafeArea()
            VStack(spacing: 16) {
                StatusCard(
                    icon: "exclamationmark.triangle.fill",
                    iconTint: AurisColor.danger,
                    title: "Couldn't generate the summary",
                    message: "The transcript was saved. Check your OpenAI key and connection, then try again.",
                    actionLabel: "Try again",
                    actionIcon: "arrow.clockwise",
                    action: { if let m = recorder.pendingMeeting { runSummary(m) } }
                )
                Button { onFinish(recorder.pendingMeeting) } label: {
                    Text("View anyway")
                        .font(AurisFont.ui(13, .medium)).foregroundStyle(AurisColor.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func importImage(_ url: URL) {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
        guard let img = NSImage(contentsOf: url),
              let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        recorder.attach(png)
    }

    private func finish() {
        Task {
            let meeting = await recorder.stopAndPersist(
                context: context,
                title: title,
                locale: appState.transcriptionLocale,
                summaryLanguage: appState.summaryLanguage
            )
            // If there is no suggestion to confirm, go straight to the summary step.
            if recorder.suggestion == nil, let meeting { runSummary(meeting) }
        }
    }

    private func runSummary(_ meeting: Meeting) {
        Task {
            await recorder.generateSummary(
                for: meeting, context: context, summaryLanguage: appState.summaryLanguage
            )
            if !recorder.summaryFailed { onFinish(meeting) }
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
