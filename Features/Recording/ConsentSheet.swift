import SwiftUI

/// "Before we start recording" consent modal. (.pen: Screen · Consentimento)
struct ConsentSheet: View {
    var onResult: (_ proceed: Bool) -> Void

    @State private var consented = false
    @State private var playNotice = true

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.shield")
                    .font(.system(size: 20))
                    .foregroundStyle(LinearGradient.auris)
                Text("Before we start recording")
                    .font(AurisFont.ui(17, .semibold))
                    .foregroundStyle(AurisColor.textPrimary)
            }

            Text("Recording laws vary by country and state. Make sure every participant is aware and agrees before you record.")
                .font(AurisFont.ui(13))
                .foregroundStyle(AurisColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Toggle(isOn: $consented) {
                Text("All participants are aware and consent")
                    .font(AurisFont.ui(13, .medium))
                    .foregroundStyle(AurisColor.textPrimary)
            }
            .toggleStyle(.checkbox)

            Toggle(isOn: $playNotice) {
                Text("Play an audible notice")
                    .font(AurisFont.ui(13))
                    .foregroundStyle(AurisColor.textSecondary)
            }
            .toggleStyle(.switch)
            .tint(AurisColor.accent)

            HStack(spacing: 12) {
                Spacer()
                Button { onResult(false) } label: {
                    Text("Cancel")
                        .font(AurisFont.ui(13, .medium))
                        .foregroundStyle(AurisColor.textSecondary)
                        .padding(.vertical, 9).padding(.horizontal, 18)
                        .overlay(Capsule().stroke(AurisColor.border, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button { onResult(true) } label: {
                    Text("Start recording")
                }
                .buttonStyle(GradientButtonStyle(verticalPadding: 9))
                .disabled(!consented)
                .opacity(consented ? 1 : 0.5)
            }
        }
        .padding(28)
        .frame(width: 460)
        .background(AurisColor.bgElevated)
        .preferredColorScheme(.dark)
    }
}
