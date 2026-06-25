import SwiftUI
import AVFoundation
import Speech

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var micGranted = false
    @State private var speechGranted = false
    @State private var apiKey = ""
    @State private var keySaved = false

    private let languages: [(code: String, label: String)] = [
        ("", String(localized: "System default")),
        ("pt-BR", "Português"),
        ("en", "English"),
        ("es", "Español")
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            content
            languagePicker
                .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AurisColor.bgWindow)
    }

    private var languagePicker: some View {
        Menu {
            Picker("", selection: Binding(
                get: { appState.interfaceLanguage },
                set: { appState.interfaceLanguage = $0 }
            )) {
                ForEach(languages, id: \.code) { lang in
                    Text(lang.label).tag(lang.code)
                }
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "globe").font(.system(size: 12))
                Text(languages.first { $0.code == appState.interfaceLanguage }?.label ?? "English")
                    .font(AurisFont.ui(12, .medium))
                Image(systemName: "chevron.down").font(.system(size: 9))
            }
            .foregroundStyle(AurisColor.textSecondary)
            .padding(.vertical, 7).padding(.horizontal, 12)
            .background(AurisColor.bgElevated, in: Capsule())
            .overlay(Capsule().stroke(AurisColor.border, lineWidth: 1))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var content: some View {
        VStack(spacing: 28) {
            Spacer()
            Image("Glyph").resizable().scaledToFit().frame(width: 64, height: 64)

            VStack(spacing: 8) {
                Text("Welcome to Auris")
                    .font(AurisFont.ui(26, .bold))
                    .foregroundStyle(AurisColor.textPrimary)
                Text("Grant a few permissions so Auris can record, transcribe and summarize your meetings.")
                    .font(AurisFont.ui(13))
                    .foregroundStyle(AurisColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)
            }

            VStack(spacing: 12) {
                permissionCard(icon: "mic.fill", title: "Microphone",
                               subtitle: "Records the microphone into your meeting.",
                               granted: micGranted, actionKey: "Allow") {
                    Task { micGranted = await requestMic() }
                }
                permissionCard(icon: "rectangle.inset.filled", title: "Screen capture",
                               subtitle: "Required to capture system audio (Zoom, Meet, Teams).",
                               granted: speechGranted, actionKey: "Allow") {
                    Task { speechGranted = await requestSpeech() }
                }
                openAICard
            }
            .frame(maxWidth: 480)

            Button { appState.completeOnboarding() } label: {
                Text("Continue").frame(maxWidth: 200)
            }
            .buttonStyle(GradientButtonStyle(verticalPadding: 11))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AurisColor.bgWindow)
    }

    private func permissionCard(icon: String, title: LocalizedStringKey, subtitle: LocalizedStringKey,
                                granted: Bool, actionKey: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(AurisColor.accentBright)
                .frame(width: 40, height: 40)
                .background(AurisColor.accentDim.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(AurisFont.ui(14, .semibold)).foregroundStyle(AurisColor.textPrimary)
                Text(subtitle).font(AurisFont.ui(12)).foregroundStyle(AurisColor.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AurisColor.success).font(.system(size: 20))
            } else {
                Button(action: action) { Text(actionKey) }
                    .buttonStyle(GradientButtonStyle(horizontalPadding: 16, verticalPadding: 8, fontSize: 13))
            }
        }
        .padding(16)
        .background(AurisColor.bgElevated, in: RoundedRectangle(cornerRadius: 12))
    }

    private var openAICard: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 18)).foregroundStyle(AurisColor.accent2)
                .frame(width: 40, height: 40)
                .background(AurisColor.accentDim.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 6) {
                Text("OpenAI key").font(AurisFont.ui(14, .semibold)).foregroundStyle(AurisColor.textPrimary)
                SecureField("", text: $apiKey, prompt: Text("Paste your OpenAI API key"))
                    .textFieldStyle(.plain)
                    .font(AurisFont.ui(12))
                    .foregroundStyle(AurisColor.textPrimary)
                    .padding(.vertical, 7).padding(.horizontal, 10)
                    .background(AurisColor.bgPanel, in: RoundedRectangle(cornerRadius: 8))
            }
            if keySaved {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(AurisColor.success).font(.system(size: 20))
            } else {
                Button {
                    KeychainStore.save(apiKey)
                    appState.refreshKeyStatus()
                    keySaved = appState.hasOpenAIKey
                } label: { Text("Connect") }
                .buttonStyle(GradientButtonStyle(horizontalPadding: 16, verticalPadding: 8, fontSize: 13))
                .disabled(apiKey.isEmpty)
                .opacity(apiKey.isEmpty ? 0.5 : 1)
            }
        }
        .padding(16)
        .background(AurisColor.bgElevated, in: RoundedRectangle(cornerRadius: 12))
    }

    private func requestMic() async -> Bool {
        await withCheckedContinuation { cont in
            AVCaptureDevice.requestAccess(for: .audio) { cont.resume(returning: $0) }
        }
    }

    private func requestSpeech() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0 == .authorized) }
        }
    }
}
