import SwiftUI
import ClackyCore

/// Draws `KeyboardLayout.macBookAirUS`, lights pressed keys, and previews a key on click.
struct KeyboardView: View {
    @ObservedObject var pressed: PressedKeys
    let onTap: (Int64) -> Void

    private let rows = KeyboardLayout.macBookAirUS
    private let gap: CGFloat = 0.08   // in key units

    var body: some View {
        GeometryReader { geo in
            let unit = geo.size.width / CGFloat(KeyboardLayout.rowUnits)
            VStack(alignment: .leading, spacing: gap * unit) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .top, spacing: gap * unit) {
                        ForEach(columns(of: row)) { column in
                            VStack(spacing: gap * unit) {
                                ForEach(column.caps) { cap in
                                    keycap(cap, unit: unit)
                                }
                            }
                        }
                    }
                }
            }
        }
        .aspectRatio((CGFloat(KeyboardLayout.rowUnits) - gap) / totalHeightUnits, contentMode: .fit)
    }

    /// Frames are (size − gap) units with gap spacing between them, so the
    /// whole board is (Σ row heights − gap) units tall.
    private var totalHeightUnits: CGFloat {
        CGFloat(rows.reduce(0.0) { $0 + ($1.first?.height ?? 1) }) - gap
    }

    /// Groups the stacked arrow pair into one column so it lays out like the real board.
    private struct Column: Identifiable { let id: String; let caps: [KeyCap] }
    private func columns(of row: [KeyCap]) -> [Column] {
        var result: [Column] = []
        for cap in row {
            if cap.id.hasSuffix("-down"), let last = result.last, last.id.hasSuffix("-up") {
                result[result.count - 1] = Column(id: last.id, caps: last.caps + [cap])
            } else {
                result.append(Column(id: cap.id, caps: [cap]))
            }
        }
        return result
    }

    @ViewBuilder
    private func keycap(_ cap: KeyCap, unit: CGFloat) -> some View {
        let isDown = cap.macKeyCode.map { pressed.codes.contains($0) } ?? false
        // Every frame is (size − gap) units; the HStack/VStack spacing supplies the gap,
        // so a stacked 0.5 + 0.5 pair ends up exactly as tall as a 1u key.
        let width = (CGFloat(cap.width) - gap) * unit
        let height = (CGFloat(cap.height) - gap) * unit
        ZStack {
            RoundedRectangle(cornerRadius: unit * 0.16, style: .continuous)
                .fill(isDown ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: unit * 0.16, style: .continuous)
                        .strokeBorder(Color.primary.opacity(isDown ? 0 : 0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(isDown ? 0.05 : 0.18), radius: isDown ? 0.5 : unit * 0.06, y: isDown ? 0.5 : unit * 0.06)
            Text(cap.label)
                .font(.system(size: max(9, unit * (cap.label.count > 2 ? 0.22 : 0.34)), design: .rounded))
                .foregroundStyle(isDown ? Color.white : Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 2)
        }
        .frame(width: width, height: height)
        .offset(y: isDown ? unit * 0.04 : 0)
        .animation(isDown ? nil : .easeOut(duration: 0.18), value: isDown)   // light instantly, fade out
        .contentShape(Rectangle())
        .onTapGesture { if let code = cap.macKeyCode { onTap(code) } }
        .accessibilityLabel(cap.label.isEmpty ? "Touch ID" : cap.label)
        .accessibilityAddTraits(.isButton)
    }
}
