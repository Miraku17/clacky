import ClackyCore

enum KeyPanTests {
    static func run() {
        TestKit.run("pan puts left-edge keys left and right-edge keys right") {
            expect(KeyboardLayout.pan(forMacKeyCode: 0x35) < -0.45, "esc \(KeyboardLayout.pan(forMacKeyCode: 0x35))")
            expect(KeyboardLayout.pan(forMacKeyCode: 0x38) < -0.4, "left shift")
            expect(KeyboardLayout.pan(forMacKeyCode: 0x24) > 0.45, "return")
            expect(KeyboardLayout.pan(forMacKeyCode: 0x7C) > 0.5, "right arrow")
        }
        TestKit.run("pan keeps space near the centre and orders keys along a row") {
            expect(abs(KeyboardLayout.pan(forMacKeyCode: 0x31)) < 0.1, "space \(KeyboardLayout.pan(forMacKeyCode: 0x31))")
            expect(KeyboardLayout.pan(forMacKeyCode: 0x00) < KeyboardLayout.pan(forMacKeyCode: 0x25), "A left of L")
            expect(KeyboardLayout.pan(forMacKeyCode: 0x0C) < KeyboardLayout.pan(forMacKeyCode: 0x23), "Q left of P")
        }
        TestKit.run("pan never exceeds the 60 percent spread and is 0 for unknown keys") {
            for cap in KeyboardLayout.macBookAirUS.flatMap({ $0 }) {
                guard let code = cap.macKeyCode else { continue }
                expect(abs(KeyboardLayout.pan(forMacKeyCode: code)) <= KeyboardLayout.maxPan + 1e-6, cap.label)
            }
            expectEqual(KeyboardLayout.pan(forMacKeyCode: 0xFF), 0)
        }
        TestKit.run("the stacked up and down arrows share a pan") {
            expectEqual(KeyboardLayout.pan(forMacKeyCode: 0x7E), KeyboardLayout.pan(forMacKeyCode: 0x7D))
        }
    }
}
