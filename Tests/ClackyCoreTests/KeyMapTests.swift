import ClackyCore

enum KeyMapTests {
    static func run() {
        TestKit.run("KeyMap maps well-known keys") {
            let expected: [Int64: Int] = [
                0x00: 30,    // A
                0x31: 57,    // Space
                0x24: 28,    // Return
                0x33: 14,    // Backspace
                0x35: 1,     // Escape
                0x30: 15,    // Tab
                0x12: 2,     // 1
                0x1D: 11,    // 0
                0x37: 3675,  // Left Command
                0x38: 42,    // Left Shift
                0x39: 58,    // Caps Lock
                0x7A: 59,    // F1
                0x6F: 88,    // F12
                0x7B: 57419, // Left arrow
                0x7E: 57416, // Up arrow
            ]
            for (mac, code) in expected {
                expectEqual(KeyMap.mechvibesCode(forMacKeyCode: mac), code, "mac 0x\(String(mac, radix: 16))")
            }
        }
        TestKit.run("KeyMap unknown key is nil") {
            expectNil(KeyMap.mechvibesCode(forMacKeyCode: 0xFF))
            expectNil(KeyMap.mechvibesCode(forMacKeyCode: 0x0A))  // ISO section key, no Mechvibes code
        }
        TestKit.run("KeyMap main block has no duplicate targets") {
            let mainBlock: [Int64] = Array(0x00...0x32).filter { $0 != 0x0A }
            let targets = mainBlock.compactMap { KeyMap.mechvibesCode(forMacKeyCode: $0) }
            expectEqual(targets.count, mainBlock.count, "every main-block key must map")
            expectEqual(Set(targets).count, targets.count, "no two keys share a sound slot")
        }
    }
}
