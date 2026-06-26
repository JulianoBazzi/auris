import SwiftUI

/// "Identify speaker" modal: name + color + known-voice suggestions. (.pen: Modal · Nomear locutor)
struct SpeakerNamingSheet: View {
    var onResult: (_ name: String?) -> Void

    @State private var name: String = ""
    @State private var colorHex: String = "#34D399"
    @State private var remember = true

    private let palette = ["#34D399", "#43A5FF", "#60A5FA", "#B07CF6", "#FBBF24", "#F87171"]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Identify speaker")
                    .font(AurisFont.ui(17, .semibold))
                    .foregroundStyle(AurisColor.textPrimary)
                Spacer()
                Button { onResult(nil) } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AurisColor.textSecondary)
                        .frame(width: 26, height: 26)
                        .background(AurisColor.bgPanel, in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Participant name")
                    .font(AurisFont.ui(12, .medium))
                    .foregroundStyle(AurisColor.textSecondary)
                TextField("", text: $name)
                    .textFieldStyle(.plain)
                    .font(AurisFont.ui(14))
                    .foregroundStyle(AurisColor.textPrimary)
                    .padding(.vertical, 10).padding(.horizontal, 12)
                    .background(AurisColor.bgPanel, in: RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(AurisColor.accent, lineWidth: 1))
            }

            HStack(spacing: 10) {
                ForEach(palette, id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 22, height: 22)
                        .overlay(Circle().stroke(.white, lineWidth: colorHex == hex ? 2 : 0))
                        .onTapGesture { colorHex = hex }
                }
            }

            Toggle(isOn: $remember) {
                Text("Remember this voice")
                    .font(AurisFont.ui(13))
                    .foregroundStyle(AurisColor.textSecondary)
            }
            .toggleStyle(.switch)
            .tint(AurisColor.accent)

            HStack(spacing: 12) {
                Button { onResult(nil) } label: {
                    Text("Cancel")
                        .font(AurisFont.ui(13, .medium))
                        .foregroundStyle(AurisColor.textSecondary)
                        .padding(.vertical, 9).padding(.horizontal, 18)
                        .overlay(Capsule().stroke(AurisColor.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                Spacer()
                Button { onResult(name) } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "checkmark").font(.system(size: 12, weight: .semibold))
                        Text("Save")
                    }
                }
                .buttonStyle(GradientButtonStyle(verticalPadding: 9))
                .disabled(name.isEmpty)
                .opacity(name.isEmpty ? 0.5 : 1)
            }
        }
        .padding(24)
        .frame(width: 360)
        .background(AurisColor.bgElevated)
        .preferredColorScheme(.dark)
    }
}
