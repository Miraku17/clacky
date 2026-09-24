import ClackyCore

enum PitchVariationTests {
    static func run() {
        TestKit.run("PitchVariation maps random 0, 0.5, 1 to the extremes and centre") {
            expectEqual(Double(PitchVariation.rate(amount: 0.03, random: { 0 })), 0.97, accuracy: 1e-6)
            expectEqual(Double(PitchVariation.rate(amount: 0.03, random: { 0.5 })), 1.0, accuracy: 1e-6)
            expectEqual(Double(PitchVariation.rate(amount: 0.03, random: { 1 })), 1.03, accuracy: 1e-6)
        }
        TestKit.run("PitchVariation default draws stay within ±amount") {
            for _ in 0..<200 {
                let r = PitchVariation.rate()
                expect(r >= 1 - PitchVariation.defaultAmount - 1e-6 && r <= 1 + PitchVariation.defaultAmount + 1e-6, "\(r)")
            }
        }
    }
}
