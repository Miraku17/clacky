import ClackyCore

enum KeyboardLayoutTests {
    static func run() {
        TestKit.run("KeyboardLayout has the function row plus five rows") {
            expectEqual(KeyboardLayout.macBookAirUS.count, 6)
        }
        TestKit.run("KeyboardLayout every row totals 14.5 units") {
            for (i, row) in KeyboardLayout.macBookAirUS.enumerated() {
                // The stacked arrow pair shares one column: count its width once.
                let width = row.reduce(0.0) { $0 + ($1.id.hasSuffix("-down") ? 0 : $1.width) }
                expectEqual(width, KeyboardLayout.rowUnits, accuracy: 0.001, "row \(i)")
            }
        }
        TestKit.run("KeyboardLayout key codes are unique") {
            let codes = KeyboardLayout.macBookAirUS.flatMap { $0 }.compactMap(\.macKeyCode)
            expectEqual(Set(codes).count, codes.count)
            expectEqual(codes.count, 77, "MacBook Air US has 77 physical keys with a key code")
        }
        TestKit.run("KeyboardLayout every key code maps or is a modifier") {
            for cap in KeyboardLayout.macBookAirUS.flatMap({ $0 }) {
                guard let code = cap.macKeyCode else { continue }
                let mapped = KeyMap.mechvibesCode(forMacKeyCode: code) != nil
                expect(mapped || KeyboardLayout.modifierCodes.contains(code), "\(cap.label) 0x\(String(code, radix: 16))")
            }
        }
        TestKit.run("KeyboardLayout well-known keys sit where expected") {
            let rows = KeyboardLayout.macBookAirUS
            expectEqual(rows[0].first?.label, "esc")
            expectEqual(rows[2].first?.label, "tab")
            expectEqual(rows[5].first(where: { $0.label == "space" })?.width, 5)
            expectEqual(rows[5].first(where: { $0.label == "space" })?.macKeyCode, 0x31)
            expectEqual(rows[3].last?.macKeyCode, 0x24)   // return
        }
    }
}
