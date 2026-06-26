import SwiftUI

/// Post-recording AI suggestions: title, alternative, tags and accent color.
/// (.pen: Modal · Auto-título e tags — "Sugestões da IA")
struct AISuggestionsSheet: View {
    let suggestion: MeetingSuggestion
    var onApply: (_ title: String, _ tags: [String], _ colorHex: String) -> Void
    var onDiscard: () -> Void

    @State private var title: String
    @State private var tags: [String]
    @State private var selected: Set<String>
    @State private var colorHex: String
    @State private var newTag: String = ""

    private let palette = ["#43A5FF", "#34D399", "#B07CF6", "#FBBF24", "#F87171"]

    init(suggestion: MeetingSuggestion,
         onApply: @escaping (_ title: String, _ tags: [String], _ colorHex: String) -> Void,
         onDiscard: @escaping () -> Void) {
        self.suggestion = suggestion
        self.onApply = onApply
        self.onDiscard = onDiscard
        _title = State(initialValue: suggestion.title)
        _tags = State(initialValue: suggestion.tags)
        _selected = State(initialValue: Set(suggestion.tags))
        _colorHex = State(initialValue: suggestion.colorHex.isEmpty ? "#43A5FF" : suggestion.colorHex)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            titleField
            if !suggestion.alternativeTitle.isEmpty { alternative }
            tagSection
            colorSection
            buttons
        }
        .padding(24)
        .frame(width: 448)
        .background(AurisColor.bgElevated)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(AurisColor.accent.opacity(0.16)).frame(width: 40, height: 40)
                Image(systemName: "sparkles").font(.system(size: 18)).foregroundStyle(LinearGradient.auris)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("AI suggestions").font(AurisFont.ui(17, .semibold)).foregroundStyle(AurisColor.textPrimary)
                Text("Generated from the meeting transcript")
                    .font(AurisFont.ui(12)).foregroundStyle(AurisColor.textMuted)
            }
        }
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Suggested title").font(AurisFont.ui(11, .semibold)).foregroundStyle(AurisColor.textMuted)
            HStack {
                TextField("", text: $title)
                    .textFieldStyle(.plain).font(AurisFont.ui(14)).foregroundStyle(AurisColor.textPrimary)
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12)).foregroundStyle(AurisColor.textMuted)
            }
            .padding(.vertical, 11).padding(.horizontal, 12)
            .background(AurisColor.bgPanel, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(AurisColor.border, lineWidth: 1))
        }
    }

    private var alternative: some View {
        HStack(spacing: 8) {
            Text("Alternative:").font(AurisFont.ui(12)).foregroundStyle(AurisColor.textMuted)
            Button { title = suggestion.alternativeTitle } label: {
                Text(suggestion.alternativeTitle)
                    .font(AurisFont.ui(12, .medium)).foregroundStyle(AurisColor.textSecondary)
                    .padding(.vertical, 5).padding(.horizontal, 10)
                    .background(AurisColor.bgPanel, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Suggested tags").font(AurisFont.ui(11, .semibold)).foregroundStyle(AurisColor.textMuted)
            FlowRow(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Button { toggle(tag) } label: { tagChip(tag, on: selected.contains(tag)) }
                        .buttonStyle(.plain)
                }
                HStack(spacing: 5) {
                    TextField("", text: $newTag, prompt: Text("Add").foregroundStyle(AurisColor.textMuted))
                        .textFieldStyle(.plain).font(AurisFont.ui(12)).frame(width: 64)
                        .foregroundStyle(AurisColor.textPrimary)
                        .onSubmit(addTag)
                    Button(action: addTag) {
                        Image(systemName: "plus").font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AurisColor.textSecondary)
                    }.buttonStyle(.plain)
                }
                .padding(.vertical, 5).padding(.horizontal, 10)
                .overlay(Capsule().stroke(AurisColor.border, lineWidth: 1))
            }
        }
    }

    private func tagChip(_ tag: String, on: Bool) -> some View {
        HStack(spacing: 6) {
            Circle().fill(Color(hex: colorHex)).frame(width: 6, height: 6)
            Text(tag).font(AurisFont.ui(12, .medium)).foregroundStyle(on ? AurisColor.textPrimary : AurisColor.textSecondary)
            if on { Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(AurisColor.success) }
        }
        .padding(.vertical, 5).padding(.horizontal, 10)
        .background((on ? AurisColor.accent.opacity(0.16) : AurisColor.bgPanel), in: Capsule())
        .overlay(Capsule().stroke(on ? AurisColor.accent.opacity(0.5) : AurisColor.border, lineWidth: 1))
    }

    private var colorSection: some View {
        HStack(spacing: 12) {
            Text("Meeting color").font(AurisFont.ui(12)).foregroundStyle(AurisColor.textSecondary)
            Spacer()
            ForEach(palette, id: \.self) { hex in
                Circle().fill(Color(hex: hex)).frame(width: 22, height: 22)
                    .overlay(Circle().stroke(.white, lineWidth: colorHex == hex ? 2 : 0))
                    .onTapGesture { colorHex = hex }
            }
        }
    }

    private var buttons: some View {
        HStack(spacing: 12) {
            Button(action: onDiscard) {
                Text("Discard")
                    .font(AurisFont.ui(13, .medium)).foregroundStyle(AurisColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .overlay(Capsule().stroke(AurisColor.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            Button { onApply(title, Array(tags.filter(selected.contains)), colorHex) } label: {
                HStack(spacing: 7) {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .semibold))
                    Text("Apply suggestions")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(GradientButtonStyle(verticalPadding: 10))
        }
    }

    private func toggle(_ tag: String) {
        if selected.contains(tag) { selected.remove(tag) } else { selected.insert(tag) }
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { newTag = ""; return }
        tags.append(trimmed)
        selected.insert(trimmed)
        newTag = ""
    }
}

/// Minimal wrapping row layout for chips (SwiftUI `Layout`).
struct FlowRow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for v in subviews {
            let size = v.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for v in subviews {
            let size = v.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            v.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
