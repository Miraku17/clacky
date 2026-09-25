import SwiftUI
import ClackyCore

/// Draws `KeyboardLayout.macBookAirUS`, lights pressed keys, and previews a key on click.
struct KeyboardView: View {
    @ObservedObject var pressed: PressedKeys
    let onTap: (Int64) -> Void

    @Environment(\.colorScheme) private var scheme
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

    /// One size per legend class, so F1 matches F12 and fn matches control:
    /// single-character typing keys are large, arrow glyphs medium, word legends small.
    private func legendScale(_ cap: KeyCap) -> CGFloat {
        if cap.tone == .alpha && cap.label.count == 1 { return 0.32 }
        if cap.label.count == 1 { return 0.22 }
        return 0.18
    }

    @ViewBuilder
    private func keycap(_ cap: KeyCap, unit: CGFloat) -> some View {
        let isDown = cap.macKeyCode.map { pressed.codes.contains($0) } ?? false
        // Every frame is (size − gap) units; the HStack/VStack spacing supplies the gap,
        // so a stacked 0.5 + 0.5 pair ends up exactly as tall as a 1u key.
        let width = (CGFloat(cap.width) - gap) * unit
        let height = (CGFloat(cap.height) - gap) * unit
        let palette = cap.tone == .alpha ? KeycapPalette.alpha(scheme) : KeycapPalette.modifier(scheme)
        Keycap3D(palette: palette, pressed: isDown,
                 depth: max(2, unit * (cap.height < 1 ? 0.07 : 0.1)),
                 cornerRadius: unit * 0.14) {
            Text(cap.label)
                .font(.system(size: max(9, unit * legendScale(cap)),
                              weight: cap.tone == .alpha ? .semibold : .medium, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 2)
        }
        .frame(width: width, height: height)
        .animation(isDown ? .easeOut(duration: 0.03) : .spring(response: 0.22, dampingFraction: 0.6), value: isDown)
        .contentShape(Rectangle())
        .onTapGesture { if let code = cap.macKeyCode { onTap(code) } }
        .accessibilityLabel(cap.label.isEmpty ? "Touch ID" : cap.label)
        .accessibilityAddTraits(cap.macKeyCode == nil ? [] : .isButton)
    }
}
