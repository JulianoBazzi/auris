import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var apiKey: String = ""

    private let locales = ["en-US", "pt-BR", "es-ES", "fr-FR", "de-DE"]
    private let summaryLangs = ["en", "pt-BR", "es"]
    private let uiLangs = ["", "en", "pt-BR", "es"]

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

            picker("Transcription language", selection: $appState.transcriptionLocale, options: locales) { $0 }
            picker("Summary language", selection: $appState.summaryLanguage, options: summaryLangs) { $0.uppercased() }
            picker("Interface language", selection: $appState.interfaceLanguage, options: uiLangs) {
                $0.isEmpty ? String(localized: "System default") : $0
            }

            Spacer()
        }
        .padding(24)
        .frame(width: 440, height: 420)
        .background(AurisColor.bgElevated)
        .preferredColorScheme(.dark)
        .onAppear { appState.refreshKeyStatus() }
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
