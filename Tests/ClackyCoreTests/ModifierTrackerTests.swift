import ClackyCore

enum ModifierTrackerTests {
    static let shift: UInt64 = 0x20000
    static let leftShift: Int64 = 0x38
    static let rightShift: Int64 = 0x3C

    static func run() {
        TestKit.run("ModifierTracker press then release") {
            var t = ModifierTracker()
            expect(t.isPress(keyCode: leftShift, flags: shift))
            expect(!t.isPress(keyCode: leftShift, flags: 0))
        }
        TestKit.run("ModifierTracker second shift while first held") {
            var t = ModifierTracker()
            expect(t.isPress(keyCode: leftShift, flags: shift))
            expect(t.isPress(keyCode: rightShift, flags: shift), "right shift down is a press")
            expect(!t.isPress(keyCode: rightShift, flags: shift), "right shift up while left held is a release")
            expect(!t.isPress(keyCode: leftShift, flags: 0))
        }
        TestKit.run("ModifierTracker caps lock always plays") {
            var t = ModifierTracker()
            expect(t.isPress(keyCode: 0x39, flags: 0x10000))
            expect(t.isPress(keyCode: 0x39, flags: 0))
        }
        TestKit.run("ModifierTracker unknown key code is not a press") {
            var t = ModifierTracker()
            expect(!t.isPress(keyCode: 0x00, flags: shift))
        }
    }
}
