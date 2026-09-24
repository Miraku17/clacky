import Foundation

public final class Settings {
    private let defaults: UserDefaults
    private enum Key { static let enabled = "enabled", volume = "volume", pack = "selectedPackName" }

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public var enabled: Bool {
        get { defaults.object(forKey: Key.enabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.enabled) }
    }

    public var volume: Float {
        get { defaults.object(forKey: Key.volume) as? Float ?? 0.5 }
        set { defaults.set(newValue, forKey: Key.volume) }
    }

    public var selectedPackName: String? {
        get { defaults.string(forKey: Key.pack) }
        set { defaults.set(newValue, forKey: Key.pack) }
    }
}
