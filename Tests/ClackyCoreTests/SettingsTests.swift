import Foundation
import ClackyCore

enum SettingsTests {
    private static func withDefaults(_ body: (UserDefaults) throws -> Void) rethrows {
        let suite = "clacky-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults)
    }

    static func run() {
        TestKit.run("Settings defaults") {
            withDefaults { defaults in
                let s = Settings(defaults: defaults)
                expect(s.enabled)
                expectEqual(s.volume, 0.5)
                expectNil(s.selectedPackName)
            }
        }
        TestKit.run("Settings round trip") {
            withDefaults { defaults in
                let s = Settings(defaults: defaults)
                s.enabled = false
                s.volume = 0.25
                s.selectedPackName = "holy-pandas"
                let again = Settings(defaults: defaults)
                expect(!again.enabled)
                expectEqual(again.volume, 0.25)
                expectEqual(again.selectedPackName, "holy-pandas")
            }
        }
    }
}

enum SettingsV2Tests {
    private static func withDefaults(_ body: (UserDefaults) throws -> Void) rethrows {
        let suite = "clacky-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults)
    }
    static func run() {
        TestKit.run("Settings release and pitch default on") {
            withDefaults { d in
                let s = Settings(defaults: d)
                expect(s.releaseSounds)
                expect(s.pitchVariation)
            }
        }
        TestKit.run("Settings release and pitch round trip") {
            withDefaults { d in
                let s = Settings(defaults: d)
                s.releaseSounds = false
                s.pitchVariation = false
                expect(!Settings(defaults: d).releaseSounds)
                expect(!Settings(defaults: d).pitchVariation)
            }
        }
    }
}

enum SettingsStereoTests {
    static func run() {
        TestKit.run("Settings stereo defaults on and round-trips") {
            let suite = "clacky-tests-\(UUID().uuidString)"
            let d = UserDefaults(suiteName: suite)!
            defer { d.removePersistentDomain(forName: suite) }
            expect(Settings(defaults: d).stereo)
            Settings(defaults: d).stereo = false
            expect(!Settings(defaults: d).stereo)
        }
    }
}
