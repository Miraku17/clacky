/// A small random playback-rate offset so repeated keys do not sound identical.
public enum PitchVariation {
    public static let defaultAmount: Float = 0.03

    /// `random` returns a value in 0…1; the result is `1 ± amount`.
    public static func rate(amount: Float = defaultAmount, random: () -> Float = { Float.random(in: 0...1) }) -> Float {
        1 + amount * (2 * random() - 1)
    }
}
