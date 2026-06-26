import SwiftUI

/// Full-screen settings, matching the .pen "Screen · Configurações" — header + two columns of cards.
struct SettingsView: View {
    @Environment(AppState.self) private var appState
    var onClose: () -> Void = {}

    @State private var apiKey: String = ""

    private let models = ["gpt-5.5", "gpt-5.4", "gpt-5.4-mini", "gpt-4o", "gpt-4o-mini", "gpt-4.1", "gpt-4.1-mini"]
    private let locales = ["en-US", "pt-BR", "es-ES", "fr-FR", "de-DE"]
    private let summaryLangs = ["en", "pt-BR", "es"]
    private let uiLangs = ["", "en", "pt-BR", "es"]

    private let cardFill = Color(hex: "#121B2E")

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                HStack(alignment: .top, spacing: 20) {
                    VStack(spacing: 20) { aiCard; transcriptionCard }
                    VStack(spacing: 20) { usageCard; generalCard }
                }
                .padding(.vertical, 22)
                .padding(.horizontal, 28)
            }
        }
        .background(AurisColor.bgPanel)
        .onAppear { appState.refreshKeyStatus() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Settings").font(AurisFont.ui(21, .semibold)).foregroundStyle(AurisColor.textPrimary)
                Text("Account, audio and AI integration")
                    .font(AurisFont.ui(12)).foregroundStyle(AurisColor.textMuted)
            }
            Spacer()
            Button { onClose() } label: {
                Text("Done")
                    .font(AurisFont.ui(13, .medium)).foregroundStyle(AurisColor.textSecondary)
                    .padding(.vertical, 9).padding(.horizontal, 18)
                    .overlay(Capsule().stroke(AurisColor.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 28)
        .overlay(alignment: .bottom) { Rectangle().fill(AurisColor.borderSubtle).frame(height: 1) }
    }

    // MARK: - Cards

    private var aiCard: some View {
        card(icon: "sparkles", title: "Artificial intelligence") {
            field("OpenAI API key") {
                HStack {
                    SecureField("", text: $apiKey, prompt: Text("Paste your OpenAI API key"))
                        .textFieldStyle(.plain).font(AurisFont.ui(13)).foregroundStyle(AurisColor.textPrimary)
                    Button { saveKey() } label: { Text("Connect") }
                        .buttonStyle(GradientButtonStyle(horizontalPadding: 14, verticalPadding: 7, fontSize: 12))
                        .disabled(apiKey.isEmpty).opacity(apiKey.isEmpty ? 0.5 : 1)
                }
                .padding(.vertical, 8).padding(.horizontal, 12)
                .background(AurisColor.bgPanel, in: RoundedRectangle(cornerRadius: 9))
            }
            pickerRow("Model", selection: bind(\.summaryModel), options: models) { $0 }
            pickerRow("Summary language", selection: bind(\.summaryLanguage), options: summaryLangs) { $0.uppercased() }
        }
    }

    private var transcriptionCard: some View {
        card(icon: "waveform", title: "Transcription & speakers") {
            pickerRow("Transcription language", selection: bind(\.transcriptionLocale), options: locales) { $0 }
            field("Your name") {
                TextField("", text: bind(\.userDisplayName), prompt: Text("Me"))
                    .textFieldStyle(.plain).font(AurisFont.ui(13)).foregroundStyle(AurisColor.textPrimary)
                    .padding(.vertical, 8).padding(.horizontal, 12)
                    .background(AurisColor.bgPanel, in: RoundedRectangle(cornerRadius: 9))
            }
            toggleRow("Transcribe system audio", isOn: bind(\.transcribeSystemAudio))
            toggleRow("Play an audible notice", isOn: bind(\.playNotice))
        }
    }

    private var generalCard: some View {
        card(icon: "gearshape", title: "General") {
            pickerRow("Interface language", selection: bind(\.interfaceLanguage), options: uiLangs) {
                $0.isEmpty ? String(localized: "System default") : $0
            }
            HStack {
                Text("Version").font(AurisFont.ui(13)).foregroundStyle(AurisColor.textSecondary)
                Spacer()
                Text("Auris · v0.1.0").font(AurisFont.mono(12)).foregroundStyle(AurisColor.textMuted)
            }
        }
    }

    private var usageCard: some View {
        card(icon: "chart.bar.fill", title: "API usage (GPT)") {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "$%.2f", UsageStore.estimatedCostUSD))
                    .font(AurisFont.ui(26, .bold)).foregroundStyle(AurisColor.textPrimary)
                Text("estimated").font(AurisFont.ui(11)).foregroundStyle(AurisColor.textMuted)
            }
            HStack(spacing: 28) {
                usageStat("\(UsageStore.summaryCount)", "Summaries")
                usageStat(formatTokens(UsageStore.tokenCount), "Tokens")
                usageStat(appState.summaryModel, "Model")
            }
        }
    }

    // MARK: - Building blocks

    private func card<Content: View>(icon: String, title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(AurisColor.accent.opacity(0.12)).frame(width: 30, height: 30)
                    Image(systemName: icon).font(.system(size: 14)).foregroundStyle(AurisColor.accentBright)
                }
                Text(title).font(AurisFont.ui(14, .semibold)).foregroundStyle(AurisColor.textPrimary)
            }
            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardFill, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AurisColor.borderSubtle, lineWidth: 1))
    }

    private func field<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(AurisFont.ui(12, .medium)).foregroundStyle(AurisColor.textSecondary)
            content()
        }
    }

    private func pickerRow(_ title: LocalizedStringKey, selection: Binding<String>, options: [String],
                           label: @escaping (String) -> String) -> some View {
        HStack {
            Text(title).font(AurisFont.ui(13)).foregroundStyle(AurisColor.textSecondary)
            Spacer()
            Picker("", selection: selection) {
                ForEach(options, id: \.self) { Text(label($0)).tag($0) }
            }
            .labelsHidden().pickerStyle(.menu).tint(AurisColor.textPrimary).fixedSize()
        }
    }

    private func toggleRow(_ title: LocalizedStringKey, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title).font(AurisFont.ui(13)).foregroundStyle(AurisColor.textSecondary)
        }
        .toggleStyle(.switch).tint(AurisColor.accent)
    }

    private func usageStat(_ value: String, _ label: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(AurisFont.ui(14, .semibold)).foregroundStyle(AurisColor.textPrimary)
            Text(label).font(AurisFont.ui(11)).foregroundStyle(AurisColor.textMuted)
        }
    }

    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.2fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }

    private func bind<T>(_ keyPath: ReferenceWritableKeyPath<AppState, T>) -> Binding<T> {
        Binding(get: { appState[keyPath: keyPath] }, set: { appState[keyPath: keyPath] = $0 })
    }

    private func saveKey() {
        guard !apiKey.isEmpty else { return }
        KeychainStore.save(apiKey)
        appState.refreshKeyStatus()
        apiKey = ""
    }

}
