import Foundation
import ClackyCore

enum KeycapThemeTests {
    static func run() {
        TestKit.run("Contrast ratio matches the WCAG reference points") {
            expectEqual(Contrast.ratio(RGB(0, 0, 0), RGB(255, 255, 255)), 21, accuracy: 0.01)
            expectEqual(Contrast.ratio(RGB(120, 120, 120), RGB(120, 120, 120)), 1, accuracy: 0.0001)
            expectEqual(Contrast.ratio(RGB(255, 255, 255), RGB(0, 0, 0)), 21, accuracy: 0.01)
        }
        TestKit.run("KeycapTheme offers Classic, Midnight, Pastel and Retro with unique ids") {
            expectEqual(KeycapTheme.all.map(\.name), ["Classic", "Midnight", "Pastel", "Retro"])
            expectEqual(Set(KeycapTheme.all.map(\.id)).count, 4)
        }
        TestKit.run("KeycapTheme.named falls back to Classic for unknown ids") {
            expectEqual(KeycapTheme.named("retro").id, "retro")
            expectEqual(KeycapTheme.named("nope").id, "classic")
        }
        TestKit.run("every legend is readable on its keycap in every theme and mode") {
            let codes: [Int64] = [0x00, 0x38, 0x35, 0x31]   // A, shift, esc, space
            for theme in KeycapTheme.all {
                for dark in [false, true] {
                    for code in codes {
                        let tone: KeyCap.Tone = [0x38, 0x35].contains(code) ? .modifier : .alpha
                        let c = theme.colors(tone: tone, keyCode: code, dark: dark)
                        for face in [c.face, c.faceBottom] {
                            let ratio = Contrast.ratio(c.legend, face)
                            expect(ratio >= 4.5, "\(theme.name) \(dark ? "dark" : "light") 0x\(String(code, radix: 16)): \(String(format: "%.2f", ratio))")
                        }
                    }
                }
            }
        }
        TestKit.run("Retro paints Esc red and leaves other keys alone") {
            let esc = KeycapTheme.retro.colors(tone: .modifier, keyCode: 0x35, dark: false)
            let shift = KeycapTheme.retro.colors(tone: .modifier, keyCode: 0x38, dark: false)
            expect(esc.face.r > esc.face.g + 60, "esc should be red, got \(esc.face)")
            expect(esc != shift)
            expectEqual(KeycapTheme.classic.colors(tone: .modifier, keyCode: 0x35, dark: false),
                        KeycapTheme.classic.colors(tone: .modifier, keyCode: 0x38, dark: false))
        }
        TestKit.run("Classic follows light and dark mode; the others look the same in both") {
            expect(KeycapTheme.classic.colors(tone: .alpha, keyCode: 0x00, dark: false)
                   != KeycapTheme.classic.colors(tone: .alpha, keyCode: 0x00, dark: true))
            for theme in [KeycapTheme.midnight, .pastel, .retro] {
                expectEqual(theme.colors(tone: .alpha, keyCode: 0x00, dark: false),
                            theme.colors(tone: .alpha, keyCode: 0x00, dark: true), theme.name)
            }
        }
        TestKit.run("Classic keeps its cream alphas") {
            expectEqual(KeycapTheme.classic.colors(tone: .alpha, keyCode: 0x00, dark: false).face, RGB(252, 247, 238))
        }
    }
}

enum SettingsThemeTests {
    static func run() {
        TestKit.run("Settings keycap theme defaults to classic and round-trips") {
            let suite = "clacky-tests-\(UUID().uuidString)"
            let d = UserDefaults(suiteName: suite)!
            defer { d.removePersistentDomain(forName: suite) }
            expectEqual(Settings(defaults: d).keycapTheme, "classic")
            Settings(defaults: d).keycapTheme = "pastel"
            expectEqual(Settings(defaults: d).keycapTheme, "pastel")
        }
    }
}
