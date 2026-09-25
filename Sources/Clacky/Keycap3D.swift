import SwiftUI

/// Colours for a two-tone keycap set, matched to the app icon.
/// Light mode: cream alphas and slate modifiers. Dark mode: charcoal set, light legends.
struct KeycapPalette {
    let face: Color
    let faceBottom: Color
    let wall: Color
    let legend: Color

    static func alpha(_ scheme: ColorScheme) -> KeycapPalette {
        scheme == .dark
            ? KeycapPalette(face: .rgb(96, 101, 110), faceBottom: .rgb(82, 87, 96), wall: .rgb(48, 51, 57), legend: .rgb(244, 240, 230))
            : KeycapPalette(face: .rgb(252, 247, 238), faceBottom: .rgb(238, 229, 212), wall: .rgb(206, 190, 160), legend: .rgb(41, 42, 46))
    }

    static func modifier(_ scheme: ColorScheme) -> KeycapPalette {
        scheme == .dark
            ? KeycapPalette(face: .rgb(46, 49, 55), faceBottom: .rgb(38, 41, 46), wall: .rgb(20, 22, 25), legend: .rgb(190, 196, 206))
            : KeycapPalette(face: .rgb(126, 136, 150), faceBottom: .rgb(108, 117, 131), wall: .rgb(72, 79, 90), legend: .rgb(248, 248, 250))
    }

    /// The mint of the icon's sound arcs, used for the pressed glow.
    static let glow = Color.rgb(46, 178, 158)
}

extension Color {
    static func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: 1)
    }
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
                            .fill(KeycapPalette.glow.opacity(pressed ? 0.38 : 0))
                            .blendMode(.plusLighter)
                    )
                    .overlay(label().foregroundStyle(palette.legend))
                    .frame(width: geo.size.width - inset * 2, height: max(0, faceHeight))
                    .offset(x: inset, y: inset * 0.5 + travel)
            }
        }
        .shadow(color: KeycapPalette.glow.opacity(pressed ? 0.45 : 0), radius: pressed ? depth * 1.6 : 0)
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
