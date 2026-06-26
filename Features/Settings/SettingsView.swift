import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var apiKey: String = ""

    private let locales = ["en-US", "pt-BR", "es-ES", "fr-FR", "de-DE"]
    private let summaryLangs = ["en", "pt-BR", "es"]
    private let uiLangs = ["", "en", "pt-BR", "es"]
    private let models = ["gpt-5.5", "gpt-5.4", "gpt-5.4-mini", "gpt-4o", "gpt-4o-mini", "gpt-4.1", "gpt-4.1-mini"]

    var body: some View {
        @Bindable var appState = appState
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text("Settings").font(AurisFont.ui(18, .semibold)).foregroundStyle(AurisColor.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AurisColor.textSecondary)
                        .frame(width: 26, height: 26)
                        .background(AurisColor.bgPanel, in: RoundedRectangle(cornerRadius: 7))
                }.buttonStyle(.plain)
            }

            field("OpenAI API key") {
                HStack {
                    SecureField("", text: $apiKey, prompt: Text("Paste your OpenAI API key"))
                        .textFieldStyle(.plain).font(AurisFont.ui(13)).foregroundStyle(AurisColor.textPrimary)
                    Button {
                        KeychainStore.save(apiKey); appState.refreshKeyStatus(); apiKey = ""
                    } label: { Text("Save") }
                        .buttonStyle(GradientButtonStyle(horizontalPadding: 14, verticalPadding: 7, fontSize: 12))
                        .disabled(apiKey.isEmpty).opacity(apiKey.isEmpty ? 0.5 : 1)
                }
                .padding(.vertical, 8).padding(.horizontal, 12)
                .background(AurisColor.bgPanel, in: RoundedRectangle(cornerRadius: 9))
            }

            field("Your name") {
                TextField("", text: $appState.userDisplayName, prompt: Text("Me"))
                    .textFieldStyle(.plain).font(AurisFont.ui(13)).foregroundStyle(AurisColor.textPrimary)
                    .padding(.vertical, 8).padding(.horizontal, 12)
                    .background(AurisColor.bgPanel, in: RoundedRectangle(cornerRadius: 9))
            }

            picker("GPT model", selection: $appState.summaryModel, options: models) { $0 }
            picker("Transcription language", selection: $appState.transcriptionLocale, options: locales) { $0 }
            picker("Summary language", selection: $appState.summaryLanguage, options: summaryLangs) { $0.uppercased() }
            picker("Interface language", selection: $appState.interfaceLanguage, options: uiLangs) {
                $0.isEmpty ? String(localized: "System default") : $0
            }

            usageCard

            Spacer()
        }
        .padding(24)
        .frame(width: 440, height: 590)
        .background(AurisColor.bgElevated)
        .preferredColorScheme(.dark)
        .onAppear { appState.refreshKeyStatus() }
    }

    private var usageCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("API usage (GPT)", systemImage: "chart.bar.fill")
                    .font(AurisFont.ui(13, .semibold)).foregroundStyle(AurisColor.textSecondary)
                Spacer()
                Text(appState.summaryModel).font(AurisFont.mono(11)).foregroundStyle(AurisColor.textMuted)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "$%.2f", UsageStore.estimatedCostUSD))
                    .font(AurisFont.ui(26, .bold)).foregroundStyle(AurisColor.textPrimary)
                Text("estimated").font(AurisFont.ui(11)).foregroundStyle(AurisColor.textMuted)
            }
            HStack(spacing: 28) {
                usageStat("\(UsageStore.summaryCount)", "Summaries")
                usageStat(formatTokens(UsageStore.tokenCount), "Tokens")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AurisColor.bgPanel, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AurisColor.borderSubtle, lineWidth: 1))
    }

    private func usageStat(_ value: String, _ label: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(AurisFont.ui(15, .semibold)).foregroundStyle(AurisColor.textPrimary)
            Text(label).font(AurisFont.ui(11)).foregroundStyle(AurisColor.textMuted)
        }
    }

    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.2fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }

    private func field<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(AurisFont.ui(12, .medium)).foregroundStyle(AurisColor.textSecondary)
            content()
        }
    }

    private func picker(_ title: LocalizedStringKey, selection: Binding<String>, options: [String],
                        label: @escaping (String) -> String) -> some View {
        field(title) {
            Picker("", selection: selection) {
                ForEach(options, id: \.self) { Text(label($0)).tag($0) }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(AurisColor.textPrimary)
        }
    }
}
