import SwiftUI
import ClackyCore


/// Colours for one keycap, resolved from the current `KeycapTheme`.
struct KeycapPalette {
    let face: Color
    let faceBottom: Color
    let wall: Color
    let legend: Color
    let glow: Color

    init(_ c: CapColors, glow: RGB) {
        face = Color(c.face); faceBottom = Color(c.faceBottom); wall = Color(c.wall); legend = Color(c.legend)
        self.glow = Color(glow)
    }

    static func resolve(_ theme: KeycapTheme, tone: KeyCap.Tone, keyCode: Int64?, scheme: ColorScheme) -> KeycapPalette {
        KeycapPalette(theme.colors(tone: tone, keyCode: keyCode, dark: scheme == .dark), glow: theme.glow)
    }
}

private struct KeycapThemeKey: EnvironmentKey {
    static let defaultValue = KeycapTheme.classic
}

extension EnvironmentValues {
    /// The keycap set used by every Keycap3D below this point.
    var keycapTheme: KeycapTheme {
        get { self[KeycapThemeKey.self] }
        set { self[KeycapThemeKey.self] = newValue }
    }
}

extension Color {
    static func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: 1)
    }

    init(_ c: RGB) { self.init(.sRGB, red: c.r / 255, green: c.g / 255, blue: c.b / 255, opacity: 1) }
}

/// A keycap with visible depth: a side wall below a gradient top face, a thin
/// highlight along the face's upper edge, and a shadow onto the plate.
/// Pressing sinks the face into the wall and lights it with a mint glow.
struct Keycap3D<Label: View>: View {
    let palette: KeycapPalette
    let pressed: Bool
    /// Wall height at rest, in points. The face travels this far when pressed.
    let depth: CGFloat
    let cornerRadius: CGFloat
    @ViewBuilder let label: () -> Label

    var body: some View {
        let travel = pressed ? depth * 0.8 : 0
        ZStack(alignment: .top) {
            // Side wall: the full cap footprint, darker, with a soft drop shadow.
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(LinearGradient(colors: [palette.wall.opacity(0.92), palette.wall],
                                     startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(pressed ? 0.18 : 0.32),
                        radius: pressed ? 1 : depth * 0.9, y: pressed ? 0.5 : depth * 0.7)

            // Top face: inset from the wall's sides, sits `depth` above its bottom edge.
            GeometryReader { geo in
                let inset = max(1, depth * 0.35)
                let faceHeight = geo.size.height - depth - inset
                RoundedRectangle(cornerRadius: cornerRadius * 0.85, style: .continuous)
                    .fill(LinearGradient(colors: [palette.face, palette.faceBottom],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(
                        // Upper-edge highlight, the light catching a slightly domed face.
                        RoundedRectangle(cornerRadius: cornerRadius * 0.85, style: .continuous)
                            .strokeBorder(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0)],
                                                         startPoint: .top, endPoint: .center), lineWidth: 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius * 0.85, style: .continuous)
                            .fill(palette.glow.opacity(pressed ? 0.38 : 0))
                            .blendMode(.plusLighter)
                    )
                    .overlay(label().foregroundStyle(palette.legend))
                    .frame(width: geo.size.width - inset * 2, height: max(0, faceHeight))
                    .offset(x: inset, y: inset * 0.5 + travel)
            }
        }
        .shadow(color: palette.glow.opacity(pressed ? 0.45 : 0), radius: pressed ? depth * 1.6 : 0)
    }
}

/// The plate the keys sit in: dark brushed-aluminum look with an inner rim.
struct KeyboardChassis<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    let padding: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: padding * 1.4, style: .continuous)
                    .fill(LinearGradient(colors: scheme == .dark
                                         ? [.rgb(58, 62, 70), .rgb(34, 37, 42)]
                                         : [.rgb(70, 76, 86), .rgb(44, 48, 56)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(
                        RoundedRectangle(cornerRadius: padding * 1.4, style: .continuous)
                            .strokeBorder(LinearGradient(colors: [.white.opacity(0.22), .black.opacity(0.35)],
                                                         startPoint: .top, endPoint: .bottom), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.35), radius: padding, y: padding * 0.5)
            )
    }
}
