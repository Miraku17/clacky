import Foundation
import ClackyCore

enum MuteTests {
    static func run() {
        TestKit.run("MutedApps adds once, ignores Clacky itself and empty ids, keeps order") {
            var list = MutedApps(bundleIDs: [])
            list.add("us.zoom.xos")
            list.add("com.apple.Safari")
            list.add("us.zoom.xos")
            list.add("com.zianvalles.clacky")
            list.add("")
            expectEqual(list.bundleIDs, ["us.zoom.xos", "com.apple.Safari"])
        }
        TestKit.run("MutedApps removes and answers contains") {
            var list = MutedApps(bundleIDs: ["a", "b", "c"])
            list.remove("b")
            expectEqual(list.bundleIDs, ["a", "c"])
            expect(list.contains("a"))
            expect(!list.contains("b"))
            expect(!list.contains(nil))
        }
        TestKit.run("SoundGate is audible when enabled and the front app is not muted") {
            expectNil(SoundGate.reason(enabled: true, frontmostBundleID: "com.apple.Safari", mutedApps: MutedApps(bundleIDs: ["us.zoom.xos"])))
            expectNil(SoundGate.reason(enabled: true, frontmostBundleID: nil, mutedApps: MutedApps(bundleIDs: ["us.zoom.xos"])))
        }
        TestKit.run("SoundGate reports off before a muted app") {
            expectEqual(SoundGate.reason(enabled: false, frontmostBundleID: "us.zoom.xos", mutedApps: MutedApps(bundleIDs: ["us.zoom.xos"])), .off)
        }
        TestKit.run("SoundGate reports the muted front app") {
            expectEqual(SoundGate.reason(enabled: true, frontmostBundleID: "us.zoom.xos", mutedApps: MutedApps(bundleIDs: ["us.zoom.xos"])),
                        .mutedIn("us.zoom.xos"))
        }
        TestKit.run("StatusText covers every state in priority order") {
            expectEqual(StatusText.make(hasPermission: false, listening: false, reason: nil, appName: nil), "Needs keyboard access")
            expectEqual(StatusText.make(hasPermission: true, listening: true, reason: .off, appName: nil), "Sounds off")
            expectEqual(StatusText.make(hasPermission: true, listening: true, reason: .mutedIn("us.zoom.xos"), appName: "zoom.us"), "Muted in zoom.us")
            expectEqual(StatusText.make(hasPermission: true, listening: true, reason: .mutedIn("x.y"), appName: nil), "Muted in x.y")
            expectEqual(StatusText.make(hasPermission: true, listening: true, reason: nil, appName: nil), "Listening")
            expectEqual(StatusText.make(hasPermission: true, listening: false, reason: nil, appName: nil), "Starting…")
        }
    }
}

enum SettingsMuteTests {
    static func run() {
        TestKit.run("Settings muted apps and hotkey defaults and round trip") {
            let suite = "clacky-tests-\(UUID().uuidString)"
            let d = UserDefaults(suiteName: suite)!
            defer { d.removePersistentDomain(forName: suite) }
            let s = Settings(defaults: d)
            expectEqual(s.mutedApps, [])
            expect(s.hotkeyEnabled)
            s.mutedApps = ["us.zoom.xos", "com.apple.Safari"]
            s.hotkeyEnabled = false
            expectEqual(Settings(defaults: d).mutedApps, ["us.zoom.xos", "com.apple.Safari"])
            expect(!Settings(defaults: d).hotkeyEnabled)
        }
    }
}

enum GlobalHotKeyTests {
    static func run() {
        TestKit.run("GlobalHotKey registers and unregisters the Clacky toggle combo") {
            let key = GlobalHotKey(combo: .clackyToggle) { }
            expect(key.register(), "RegisterEventHotKey should succeed for ⌃⌥⌘C")
            expect(key.isRegistered)
            key.unregister()
            expect(!key.isRegistered)
        }
        TestKit.run("GlobalHotKey toggle combo is control-option-command C") {
            expectEqual(GlobalHotKey.Combo.clackyToggle.keyCode, 0x08)
            expectEqual(GlobalHotKey.Combo.clackyToggle.display, "⌃⌥⌘C")
        }
    }
}
