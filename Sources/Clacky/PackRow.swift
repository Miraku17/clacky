import SwiftUI

/// A pack shown as a keycap: raised at rest, pressed when selected.
struct PackRow: View {
    let title: String
    let selected: Bool
    let loading: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(.body, design: .rounded, weight: selected ? .semibold : .regular))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 4)
            if loading {
                ProgressView().controlSize(.small)
            } else if selected {
                Image(systemName: "checkmark")
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(selected ? Color.accentColor.opacity(0.16) : Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(selected ? Color.accentColor.opacity(0.55) : Color.primary.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: .black.opacity(selected ? 0.06 : 0.16), radius: selected ? 0.5 : 1.5, x: 0, y: selected ? 0.5 : 2)
        )
        .offset(y: selected ? 1 : 0)
        .contentShape(Rectangle())
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
