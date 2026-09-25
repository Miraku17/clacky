import Foundation

/// An sRGB colour with 0…255 channels, kept free of SwiftUI so themes can be tested.
public struct RGB: Equatable, CustomStringConvertible {
    public let r: Double, g: Double, b: Double
    public init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }
    public var description: String { "RGB(\(Int(r)), \(Int(g)), \(Int(b)))" }
}

/// The four colours of one keycap: top face (gradient top and bottom), side wall, legend.
public struct CapColors: Equatable {
    public let face: RGB, faceBottom: RGB, wall: RGB, legend: RGB
    public init(face: RGB, faceBottom: RGB, wall: RGB, legend: RGB) {
        self.face = face; self.faceBottom = faceBottom; self.wall = wall; self.legend = legend
    }
}

public enum Contrast {
    /// WCAG 2 contrast ratio between two colours, 1 (identical) … 21 (black on white).
    public static func ratio(_ a: RGB, _ b: RGB) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    static func luminance(_ c: RGB) -> Double {
        func channel(_ v: Double) -> Double {
            let s = v / 255
            return s <= 0.04045 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b)
    }
}

/// A keycap set: colours for typing keys and for the rest, optionally different in dark mode,
/// an optional accent for particular keys, and the glow shown while a key is pressed.
public struct KeycapTheme: Identifiable, Equatable {
    public let id: String
    public let name: String
    let alphaLight: CapColors, alphaDark: CapColors
    let modifierLight: CapColors, modifierDark: CapColors
    let accent: CapColors?
    let accentKeyCodes: Set<Int64>
    public let glow: RGB

    public func colors(tone: KeyCap.Tone, keyCode: Int64?, dark: Bool) -> CapColors {
        if let accent, let keyCode, accentKeyCodes.contains(keyCode) { return accent }
        switch tone {
        case .alpha: return dark ? alphaDark : alphaLight
        case .modifier: return dark ? modifierDark : modifierLight
        }
    }

    public static let all: [KeycapTheme] = [.classic, .midnight, .pastel, .retro]

    public static func named(_ id: String) -> KeycapTheme { all.first { $0.id == id } ?? .classic }

    /// Cream and slate, from the app icon. Follows light and dark mode.
    public static let classic = KeycapTheme(
        id: "classic", name: "Classic",
        alphaLight: CapColors(face: RGB(252, 247, 238), faceBottom: RGB(238, 229, 212), wall: RGB(206, 190, 160), legend: RGB(41, 42, 46)),
        alphaDark: CapColors(face: RGB(96, 101, 110), faceBottom: RGB(82, 87, 96), wall: RGB(48, 51, 57), legend: RGB(244, 240, 230)),
        modifierLight: CapColors(face: RGB(104, 114, 128), faceBottom: RGB(90, 99, 112), wall: RGB(60, 66, 76), legend: RGB(248, 248, 250)),
        modifierDark: CapColors(face: RGB(46, 49, 55), faceBottom: RGB(38, 41, 46), wall: RGB(20, 22, 25), legend: RGB(190, 196, 206)),
        accent: nil, accentKeyCodes: [], glow: RGB(46, 178, 158))

    /// All black, grey legends, electric-blue glow.
    public static let midnight: KeycapTheme = {
        let alpha = CapColors(face: RGB(40, 42, 48), faceBottom: RGB(32, 34, 39), wall: RGB(14, 15, 18), legend: RGB(200, 204, 212))
        let mod = CapColors(face: RGB(28, 30, 34), faceBottom: RGB(22, 23, 27), wall: RGB(8, 9, 11), legend: RGB(150, 156, 166))
        return KeycapTheme(id: "midnight", name: "Midnight", alphaLight: alpha, alphaDark: alpha,
                           modifierLight: mod, modifierDark: mod, accent: nil, accentKeyCodes: [], glow: RGB(80, 160, 255))
    }()

    /// Lavender typing keys, mint modifiers, pink glow.
    public static let pastel: KeycapTheme = {
        let alpha = CapColors(face: RGB(226, 218, 245), faceBottom: RGB(212, 202, 236), wall: RGB(170, 158, 206), legend: RGB(58, 48, 92))
        let mod = CapColors(face: RGB(170, 226, 208), faceBottom: RGB(152, 212, 192), wall: RGB(104, 168, 146), legend: RGB(26, 72, 60))
        return KeycapTheme(id: "pastel", name: "Pastel", alphaLight: alpha, alphaDark: alpha,
                           modifierLight: mod, modifierDark: mod, accent: nil, accentKeyCodes: [], glow: RGB(240, 120, 170))
    }()

    /// IBM beige and grey with a red Esc, amber glow.
    public static let retro: KeycapTheme = {
        let alpha = CapColors(face: RGB(236, 230, 214), faceBottom: RGB(222, 214, 194), wall: RGB(178, 168, 144), legend: RGB(60, 58, 54))
        let mod = CapColors(face: RGB(168, 168, 162), faceBottom: RGB(152, 152, 148), wall: RGB(108, 108, 104), legend: RGB(36, 36, 34))
        let red = CapColors(face: RGB(196, 52, 44), faceBottom: RGB(176, 42, 36), wall: RGB(120, 26, 22), legend: RGB(252, 248, 244))
        return KeycapTheme(id: "retro", name: "Retro", alphaLight: alpha, alphaDark: alpha,
                           modifierLight: mod, modifierDark: mod, accent: red, accentKeyCodes: [0x35], glow: RGB(240, 160, 40))
    }()
}
