import SwiftUI

/// Confirmation modal for deleting a meeting. (.pen: Modal · Excluir reunião)
struct DeleteMeetingSheet: View {
    let meeting: Meeting
    var onCancel: () -> Void
    var onConfirm: () -> Void

    private var wordCount: Int {
        meeting.segments.reduce(0) { $0 + $1.text.split(separator: " ").count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(AurisColor.danger.opacity(0.14)).frame(width: 40, height: 40)
                Image(systemName: "trash").font(.system(size: 17)).foregroundStyle(AurisColor.danger)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Delete this meeting?")
                    .font(AurisFont.ui(17, .semibold)).foregroundStyle(AurisColor.textPrimary)
                Text("The transcript, summary and recorded audio will be permanently removed from this Mac. This action can't be undone.")
                    .font(AurisFont.ui(13)).foregroundStyle(AurisColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Circle().fill(Color(hex: meeting.colorHex)).frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(meeting.title)
                        .font(AurisFont.ui(13, .semibold)).foregroundStyle(AurisColor.textPrimary)
                    Text("\(meeting.createdAt.formatted(date: .abbreviated, time: .shortened)) · \(meeting.formattedDuration) · \(wordCount) \(String(localized: "words"))")
                        .font(AurisFont.ui(11)).foregroundStyle(AurisColor.textMuted)
                }
                Spacer()
                Image(systemName: "waveform").font(.system(size: 13)).foregroundStyle(AurisColor.textMuted)
            }
            .padding(.vertical, 12).padding(.horizontal, 14)
            .background(AurisColor.bgPanel, in: RoundedRectangle(cornerRadius: 10))

            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(AurisFont.ui(13, .medium)).foregroundStyle(AurisColor.textSecondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .overlay(Capsule().stroke(AurisColor.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                Button(action: onConfirm) {
                    HStack(spacing: 7) {
                        Image(systemName: "trash").font(.system(size: 12, weight: .semibold))
                        Text("Delete")
                    }
                    .font(AurisFont.ui(13, .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(AurisColor.danger, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .frame(width: 424)
        .background(AurisColor.bgElevated)
        .preferredColorScheme(.dark)
    }
}
