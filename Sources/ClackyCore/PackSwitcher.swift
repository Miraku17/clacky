/// Bookkeeping for asynchronous pack loads: which pack the user picked,
/// which one is loaded, and which load is in flight. Stale loads that finish
/// after a newer request are ignored so the picker, playback and the
/// persisted choice never disagree.
public struct PackSwitcher: Equatable {
    public enum Outcome: Equatable {
        /// The load matches the current request: install it.
        case apply
        /// A newer request superseded this load: drop it.
        case ignore
        /// The load failed: the selection was rolled back to the loaded pack (or nothing).
        case revert(to: String?)
    }

    public private(set) var selected: String = ""
    public private(set) var loaded: String? = nil
    public private(set) var inFlight: String? = nil

    public init() {}

    /// Records the user's choice. Returns true when the caller should start loading `name`.
    public mutating func request(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        if name == inFlight { return false }
        if inFlight == nil, name == loaded { return false }
        selected = name
        inFlight = name
        return true
    }

    /// Reports the result of the load started for `name`.
    public mutating func finished(_ name: String, success: Bool) -> Outcome {
        guard name == inFlight else { return .ignore }
        inFlight = nil
        if success {
            loaded = name
            return .apply
        }
        selected = loaded ?? ""
        return .revert(to: loaded)
    }
}
