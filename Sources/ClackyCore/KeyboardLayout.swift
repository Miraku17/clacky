/// One drawn key. Widths are in key units (a letter key is 1); the function
/// row is 0.6 high; the arrow up/down pair are 0.5 high in one 1u column.
public struct KeyCap: Identifiable, Equatable {
    public let id: String
    public let label: String
    public let macKeyCode: Int64?
    public let width: Double
    public let height: Double

    /// Two-tone keycap sets colour the typing keys differently from the rest.
    public enum Tone: Equatable { case alpha, modifier }

    /// Letters, digits, symbols and space are `.alpha`; every other key (modifiers,
    /// tab/delete/return, the function row, arrows, Touch ID) is `.modifier`.
    public var tone: Tone {
        guard height >= 1, !id.hasSuffix("-up"), !id.hasSuffix("-down"), let code = macKeyCode else { return .modifier }
        if code == 0x31 { return .alpha }                                  // space
        if KeyboardLayout.modifierCodes.contains(code) { return .modifier }
        if [0x30, 0x33, 0x24, 0x7B, 0x7C].contains(code) { return .modifier } // tab, delete, return, ◀ ▶
        return .alpha
    }
}

public enum KeyboardLayout {
    public static let rowUnits: Double = 14.5

    /// Modifier keys (plus fn and caps lock): they sound on press but are not letters or symbols.
    public static let modifierCodes: Set<Int64> = [0x38, 0x3C, 0x3B, 0x3E, 0x3A, 0x3D, 0x37, 0x36, 0x3F, 0x39]

    private typealias Spec = (label: String, code: Int64?, width: Double, height: Double)

    private static func k(_ label: String, _ code: Int64?, _ width: Double = 1, _ height: Double = 1) -> Spec {
        (label, code, width, height)
    }

    private static func row(_ index: Int, _ caps: [Spec]) -> [KeyCap] {
        caps.enumerated().map { col, cap in
            KeyCap(id: "\(index)-\(col)", label: cap.label, macKeyCode: cap.code, width: cap.width, height: cap.height)
        }
    }

    public static let macBookAirUS: [[KeyCap]] = [
        row(0, [k("esc", 0x35, 1.5, 0.6), k("F1", 0x7A, 1, 0.6), k("F2", 0x78, 1, 0.6), k("F3", 0x63, 1, 0.6),
                k("F4", 0x76, 1, 0.6), k("F5", 0x60, 1, 0.6), k("F6", 0x61, 1, 0.6), k("F7", 0x62, 1, 0.6),
                k("F8", 0x64, 1, 0.6), k("F9", 0x65, 1, 0.6), k("F10", 0x6D, 1, 0.6), k("F11", 0x67, 1, 0.6),
                k("F12", 0x6F, 1, 0.6), k("", nil, 1, 0.6)]),
        row(1, [k("`", 0x32), k("1", 0x12), k("2", 0x13), k("3", 0x14), k("4", 0x15), k("5", 0x17), k("6", 0x16),
                k("7", 0x1A), k("8", 0x1C), k("9", 0x19), k("0", 0x1D), k("-", 0x1B), k("=", 0x18), k("delete", 0x33, 1.5)]),
        row(2, [k("tab", 0x30, 1.5), k("Q", 0x0C), k("W", 0x0D), k("E", 0x0E), k("R", 0x0F), k("T", 0x11), k("Y", 0x10),
                k("U", 0x20), k("I", 0x22), k("O", 0x1F), k("P", 0x23), k("[", 0x21), k("]", 0x1E), k("\\", 0x2A)]),
        row(3, [k("caps lock", 0x39, 1.75), k("A", 0x00), k("S", 0x01), k("D", 0x02), k("F", 0x03), k("G", 0x05), k("H", 0x04),
                k("J", 0x26), k("K", 0x28), k("L", 0x25), k(";", 0x29), k("'", 0x27), k("return", 0x24, 1.75)]),
        row(4, [k("shift", 0x38, 2.25), k("Z", 0x06), k("X", 0x07), k("C", 0x08), k("V", 0x09), k("B", 0x0B), k("N", 0x2D),
                k("M", 0x2E), k(",", 0x2B), k(".", 0x2F), k("/", 0x2C), k("shift", 0x3C, 2.25)]),
        arrowsRow(),
    ]

    /// How far a key at the very edge of the board is panned (0 = centre, 1 = one ear only).
    public static let maxPan: Float = 0.6

    /// Stereo position of a key from where it sits on the drawn board: −maxPan at the
    /// left edge, +maxPan at the right, 0 for keys not on the board. Precomputed once.
    public static func pan(forMacKeyCode code: Int64) -> Float { panTable[code] ?? 0 }

    private static let panTable: [Int64: Float] = {
        var table: [Int64: Float] = [:]
        for row in macBookAirUS {
            var x = 0.0
            for cap in row {
                // The stacked ▲▼ pair shares one column: ▼ reuses ▲'s x and adds no width.
                let isDown = cap.id.hasSuffix("-down")
                let left = isDown ? x - cap.width : x
                if let code = cap.macKeyCode {
                    let centre = (left + cap.width / 2) / rowUnits          // 0…1 across the board
                    table[code] = Float(centre * 2 - 1) * maxPan
                }
                if !isDown { x += cap.width }
            }
        }
        return table
    }()

    /// Bottom row; the up/down pair shares one column and gets ids `5-<col>-up` / `5-<col>-down`.
    private static func arrowsRow() -> [KeyCap] {
        var caps = row(5, [k("fn", 0x3F), k("control", 0x3B), k("option", 0x3A), k("command", 0x37, 1.25),
                           k("space", 0x31, 5), k("command", 0x36, 1.25), k("option", 0x3D), k("◀", 0x7B)])
        let col = caps.count
        caps.append(KeyCap(id: "5-\(col)-up", label: "▲", macKeyCode: 0x7E, width: 1, height: 0.5))
        caps.append(KeyCap(id: "5-\(col)-down", label: "▼", macKeyCode: 0x7D, width: 1, height: 0.5))
        caps.append(KeyCap(id: "5-\(col + 1)", label: "▶", macKeyCode: 0x7C, width: 1, height: 1))
        return caps
    }
}
