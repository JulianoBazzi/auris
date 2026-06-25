import SwiftUI

/// Participant / filter chip: colored dot + label inside a bordered pill. (.pen: Chip)
struct Chip: View {
    let label: String
    var dotColor: Color = AurisColor.accentBright
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
            Text(label)
                .font(AurisFont.ui(12, .medium))
                .foregroundStyle(AurisColor.textPrimary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 11)
        .background(isSelected ? AurisColor.bgHover : AurisColor.bgElevated, in: Capsule())
        .overlay(Capsule().stroke(isSelected ? AurisColor.accent : AurisColor.border, lineWidth: 1))
    }
}
