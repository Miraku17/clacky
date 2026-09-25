/// The apps in which Clacky stays silent, by bundle identifier, in the order added.
public struct MutedApps: Equatable {
    public static let ownBundleID = "com.zianvalles.clacky"

    public private(set) var bundleIDs: [String]

    public init(bundleIDs: [String]) { self.bundleIDs = bundleIDs }

    /// Adds an app once. Clacky itself and empty identifiers are ignored.
    public mutating func add(_ bundleID: String) {
        guard !bundleID.isEmpty, bundleID != Self.ownBundleID, !bundleIDs.contains(bundleID) else { return }
        bundleIDs.append(bundleID)
    }

    public mutating func remove(_ bundleID: String) { bundleIDs.removeAll { $0 == bundleID } }

    public func contains(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return bundleIDs.contains(bundleID)
    }
}

/// Why keystrokes are silent right now, or nil when they are audible.
public enum SilenceReason: Equatable {
    /// The Enabled switch (or the hotkey) turned sounds off.
    case off
    /// The frontmost app is on the muted list.
    case mutedIn(String)
}

public enum SoundGate {
    /// `.off` wins over an app rule so the status says what the user did last.
    public static func reason(enabled: Bool, frontmostBundleID: String?, mutedApps: MutedApps) -> SilenceReason? {
        if !enabled { return .off }
        if mutedApps.contains(frontmostBundleID), let id = frontmostBundleID { return .mutedIn(id) }
        return nil
    }
}

public enum StatusText {
    /// The one-line status shown in the panel header and the window footer.
    public static func make(hasPermission: Bool, listening: Bool, reason: SilenceReason?, appName: String?) -> String {
        guard hasPermission else { return "Needs keyboard access" }
        switch reason {
        case .off: return "Sounds off"
        case .mutedIn(let id): return "Muted in \(appName ?? id)"
        case nil: return listening ? "Listening" : "Starting…"
        }
    }
}
