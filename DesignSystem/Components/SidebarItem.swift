import SwiftUI

/// A meeting row in the sidebar list. (.pen: SidebarItem)
struct SidebarItem: View {
    let title: String
    let meta: String
    var dotColor: Color = AurisColor.accent
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 11) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
            Image(systemName: "waveform")
                .font(.system(size: 14))
                .foregroundStyle(AurisColor.textSecondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AurisFont.ui(13, .medium))
                    .foregroundStyle(AurisColor.textPrimary)
                    .lineLimit(1)
                Text(meta)
                    .font(AurisFont.ui(11))
                    .foregroundStyle(AurisColor.textMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 11)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? AurisColor.bgHover : .clear)
        )
        .contentShape(Rectangle())
    }
}
