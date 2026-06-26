import SwiftUI
import AppKit

struct IdleView: View {
    @Bindable var recorder: RecordingViewModel
    var onStart: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer()
            if recorder.errorMessage != nil { errorState } else { content }
            Spacer()
        }
        .background(AurisColor.bgPanel)
    }

    private var errorState: some View {
        StatusCard(
            icon: "mic.slash.fill",
            iconTint: AurisColor.danger,
            title: "Microphone unavailable",
            message: "Permission was denied or no device was found. Check access in System Settings.",
            actionLabel: "Open Settings",
            actionIcon: "arrow.up.forward.app",
            action: {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                    NSWorkspace.shared.open(url)
                }
                recorder.errorMessage = nil
            }
        )
        .padding(.horizontal, 28)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("New meeting")
                    .font(AurisFont.ui(18, .semibold))
                    .foregroundStyle(AurisColor.textPrimary)
                Text("Auris waits for the microphone and system audio, transcribes on-device, and turns the conversation into a clean summary.")
                    .font(AurisFont.ui(12))
                    .foregroundStyle(AurisColor.textMuted)
                    .lineLimit(2)
                    .frame(maxWidth: 460, alignment: .leading)
            }
            Spacer()
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 28)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AurisColor.borderSubtle).frame(height: 1)
        }
    }

    private var content: some View {
        VStack(spacing: 26) {
            ZStack {
                Circle()
                    .fill(LinearGradient.auris.opacity(0.18))
                    .frame(width: 116, height: 116)
                Circle()
                    .stroke(AurisColor.accent.opacity(0.4), lineWidth: 1)
                    .frame(width: 116, height: 116)
                Image(systemName: "mic.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(LinearGradient.auris)
            }

            VStack(spacing: 8) {
                Text("Ready to listen")
                    .font(AurisFont.ui(22, .semibold))
                    .foregroundStyle(AurisColor.textPrimary)
                Text("Auris waits for the microphone and system audio, transcribes on-device, and turns the conversation into a clean summary.")
                    .font(AurisFont.ui(13))
                    .foregroundStyle(AurisColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            HStack(spacing: 12) {
                GhostControlButton(titleKey: "Microphone", systemImage: "mic", isActive: recorder.captureMic) {
                    recorder.captureMic.toggle()
                }
                GhostControlButton(titleKey: "System audio", systemImage: "speaker.wave.2", isActive: recorder.captureSystem) {
                    recorder.captureSystem.toggle()
                }
            }

            ControlButton(titleKey: "Start meeting", systemImage: "record.circle", action: onStart)
        }
        .padding(.horizontal, 28)
    }
}
