public enum ModifierEvent: Equatable { case press, release }

/// Turns `flagsChanged` events (which carry no down/up bit) into press/release
/// decisions by remembering which modifier key codes are currently held.
public struct ModifierTracker {
    private var held: Set<Int64> = []

    public init() {}

    /// Classifies a `flagsChanged` event. `flags` is `CGEvent.flags.rawValue`.
    public mutating func event(keyCode: Int64, flags: UInt64) -> ModifierEvent? {
        if keyCode == 0x39 { return .press }   // Caps Lock reports one event per tap
        guard let mask = Self.mask(for: keyCode) else { return nil }
        let flagOn = flags & mask != 0
        if flagOn, !held.contains(keyCode) { held.insert(keyCode); return .press }
        if held.contains(keyCode) { held.remove(keyCode); return .release }
        return nil
    }

    /// Kept for callers that only care about presses.
    public mutating func isPress(keyCode: Int64, flags: UInt64) -> Bool {
        event(keyCode: keyCode, flags: flags) == .press
    }

    static func mask(for keyCode: Int64) -> UInt64? {
        switch keyCode {
        case 0x38, 0x3C: return 0x20000    // shift
        case 0x3B, 0x3E: return 0x40000    // control
        case 0x3A, 0x3D: return 0x80000    // option
        case 0x37, 0x36: return 0x100000   // command
        case 0x3F:       return 0x800000   // fn
        default:         return nil
        }
    }
}
