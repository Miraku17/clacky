import SwiftUI

/// A pack shown as a wide 3D keycap: raised at rest, pressed in when selected.
struct PackRow: View {
    let title: String
    let selected: Bool
    let loading: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Keycap3D(palette: selected ? .alpha(scheme) : .modifier(scheme),
                 pressed: selected, depth: 4, cornerRadius: 9) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(.body, design: .rounded, weight: selected ? .semibold : .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                if loading {
                    ProgressView().controlSize(.small)
                } else if selected {
                    Image(systemName: "checkmark").font(.system(.caption, weight: .bold))
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 40)
        .animation(.spring(response: 0.22, dampingFraction: 0.65), value: selected)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
