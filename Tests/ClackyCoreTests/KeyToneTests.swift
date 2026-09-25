import ClackyCore

enum KeyToneTests {
    private static func cap(_ label: String) -> KeyCap? {
        KeyboardLayout.macBookAirUS.flatMap { $0 }.first { $0.label == label }
    }
    static func run() {
        TestKit.run("KeyCap tone: letters, digits, symbols and space are alpha") {
            for label in ["A", "1", ";", "space", "`"] { expectEqual(cap(label)?.tone, .alpha, label) }
        }
        TestKit.run("KeyCap tone: modifiers, edges, function row and arrows are modifier") {
            for label in ["shift", "command", "fn", "caps lock", "tab", "delete", "return", "esc", "F1", "▲", "◀", ""] {
                expectEqual(cap(label)?.tone, .modifier, label.isEmpty ? "touch id" : label)
            }
        }
    }
}
