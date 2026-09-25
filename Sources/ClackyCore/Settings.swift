import Foundation

public final class Settings {
    private let defaults: UserDefaults
    private enum Key {
        static let enabled = "enabled", volume = "volume", pack = "selectedPackName"
        static let releaseSounds = "releaseSounds", pitchVariation = "pitchVariation", stereo = "stereo"
        static let mutedApps = "mutedApps", hotkeyEnabled = "hotkeyEnabled", keycapTheme = "keycapTheme"
    }

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

    public var releaseSounds: Bool {
        get { defaults.object(forKey: Key.releaseSounds) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.releaseSounds) }
    }

    public var pitchVariation: Bool {
        get { defaults.object(forKey: Key.pitchVariation) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.pitchVariation) }
    }

    /// Pan each key by its position on the keyboard.
    public var stereo: Bool {
        get { defaults.object(forKey: Key.stereo) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.stereo) }
    }

    /// Bundle identifiers of apps in which Clacky stays silent.
    public var mutedApps: [String] {
        get { defaults.stringArray(forKey: Key.mutedApps) ?? [] }
        set { defaults.set(newValue, forKey: Key.mutedApps) }
    }

    /// Whether ⌃⌥⌘C toggles sounds from anywhere.
    public var hotkeyEnabled: Bool {
        get { defaults.object(forKey: Key.hotkeyEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.hotkeyEnabled) }
    }

    /// Id of the keycap theme (see `KeycapTheme.all`).
    public var keycapTheme: String {
        get { defaults.string(forKey: Key.keycapTheme) ?? "classic" }
        set { defaults.set(newValue, forKey: Key.keycapTheme) }
    }
}
