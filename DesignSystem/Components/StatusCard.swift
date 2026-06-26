import SwiftUI

/// Centered state card used for empty / error / call-to-action states.
/// (.pen: States · Erro, vazio e uso GPT — "Nenhuma reunião ainda", "Microfone indisponível", etc.)
struct StatusCard: View {
    let icon: String
    var iconTint: Color = AurisColor.accentBright
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var actionLabel: LocalizedStringKey?
    var actionIcon: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconTint.opacity(0.14))
                    .frame(width: 56, height: 56)
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(iconTint)
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(AurisFont.ui(16, .semibold))
                    .foregroundStyle(AurisColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(AurisFont.ui(13))
                    .foregroundStyle(AurisColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionLabel, let action {
                Button(action: action) {
                    HStack(spacing: 7) {
                        if let actionIcon {
                            Image(systemName: actionIcon).font(.system(size: 12, weight: .semibold))
                        }
                        Text(actionLabel)
                    }
                }
                .buttonStyle(GradientButtonStyle(verticalPadding: 9))
            }
        }
        .padding(28)
        .frame(maxWidth: 360)
        .background(AurisColor.bgPanel, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AurisColor.borderSubtle, lineWidth: 1))
    }
}
