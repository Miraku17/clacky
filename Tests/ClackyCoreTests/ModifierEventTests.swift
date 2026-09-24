import ClackyCore

enum ModifierEventTests {
    static let shift: UInt64 = 0x20000
    static func run() {
        TestKit.run("ModifierTracker event reports press then release") {
            var t = ModifierTracker()
            expectEqual(t.event(keyCode: 0x38, flags: shift), .press)
            expectEqual(t.event(keyCode: 0x38, flags: 0), .release)
        }
        TestKit.run("ModifierTracker event is nil for a release of a key never seen") {
            var t = ModifierTracker()
            expectNil(t.event(keyCode: 0x38, flags: 0))
            expectNil(t.event(keyCode: 0x00, flags: shift))
        }
        TestKit.run("ModifierTracker event second shift press and release while first held") {
            var t = ModifierTracker()
            expectEqual(t.event(keyCode: 0x38, flags: shift), .press)
            expectEqual(t.event(keyCode: 0x3C, flags: shift), .press)
            expectEqual(t.event(keyCode: 0x3C, flags: shift), .release)
            expectEqual(t.event(keyCode: 0x38, flags: 0), .release)
        }
        TestKit.run("ModifierTracker caps lock is always a press") {
            var t = ModifierTracker()
            expectEqual(t.event(keyCode: 0x39, flags: 0), .press)
        }
    }
}
