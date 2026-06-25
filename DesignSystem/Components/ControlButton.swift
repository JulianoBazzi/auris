import SwiftUI

/// Primary pill action with brand gradient + leading SF Symbol. (.pen: ControlButton)
struct ControlButton: View {
    let titleKey: LocalizedStringKey
    let systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                Text(titleKey)
            }
        }
        .buttonStyle(GradientButtonStyle())
    }
}

/// Bordered secondary pill with leading symbol (e.g. capture source toggles).
struct GhostControlButton: View {
    let titleKey: LocalizedStringKey
    let systemImage: String
    var isActive: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .medium))
                Text(titleKey)
            }
        }
        .buttonStyle(GhostButtonStyle())
        .overlay {
            if isActive {
                Capsule().stroke(AurisColor.accent, lineWidth: 1)
            }
        }
    }
}
