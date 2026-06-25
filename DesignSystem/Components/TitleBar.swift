import SwiftUI

/// Custom window title bar: brand centered, search + detail-panel toggle on the right. (.pen height 46)
struct TitleBar: View {
    @Binding var showDetailPanel: Bool
    var onSearch: () -> Void = {}

    var body: some View {
        HStack(spacing: 14) {
            // Leading spacer balances the trailing controls so the brand stays centered.
            Color.clear.frame(width: 64, height: 1)

            Spacer(minLength: 0)
            HStack(spacing: 8) {
                Image("Glyph")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                Text("Auris")
                    .font(AurisFont.ui(13, .semibold))
                    .foregroundStyle(AurisColor.textPrimary)
            }
            Spacer(minLength: 0)

            HStack(spacing: 6) {
                titleBarButton(symbol: "magnifyingglass", action: onSearch)
                titleBarButton(symbol: "sidebar.right") { showDetailPanel.toggle() }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 46)
        .background(AurisColor.bgSidebar)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AurisColor.borderSubtle).frame(height: 1)
        }
    }

    private func titleBarButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .foregroundStyle(AurisColor.textSecondary)
                .frame(width: 28, height: 28)
                .background(AurisColor.bgElevated.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
