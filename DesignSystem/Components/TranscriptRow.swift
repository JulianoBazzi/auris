import SwiftUI

/// A single transcript line: circular speaker avatar + name + timestamp + text. (.pen: TranscriptRow)
struct TranscriptRow: View {
    let speakerName: String
    let timestamp: String
    let text: String
    var accent: Color = AurisColor.accentBright

    private var initials: String {
        let parts = speakerName.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? "?"
        return first.uppercased()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(initials)
                .font(AurisFont.ui(14, .bold))
                .foregroundStyle(accent)
                .frame(width: 38, height: 38)
                .background(AurisColor.accentDim.opacity(0.55), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(speakerName)
                        .font(AurisFont.ui(13, .semibold))
                        .foregroundStyle(accent)
                    Text(timestamp)
                        .font(AurisFont.mono(11))
                        .foregroundStyle(AurisColor.textMuted)
                }
                Text(text)
                    .font(AurisFont.ui(14))
                    .foregroundStyle(AurisColor.textSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
