import SwiftUI

// Liquid chrome, after the Siri icon in iOS 27: white through silver into graphite and back,
// turned slightly as it breathes so the metal never looks painted on.
struct Chrome: View {
    let phase: Double
    let dark: Bool

    // A short range of greys, not the full white-to-black sweep. It is a background.
    private var greys: [Gradient.Stop] {
        let base: [(Double, Double)] = dark
            ? [(0.26, 0), (0.16, 0.3), (0.3, 0.52), (0.14, 0.78), (0.24, 1)]
            : [(0.95, 0), (0.82, 0.3), (0.96, 0.52), (0.8, 0.78), (0.92, 1)]
        return base.map { .init(color: Color(white: $0.0), location: $0.1) }
    }

    var body: some View {
        ZStack {
            LinearGradient(stops: greys, startPoint: .topLeading, endPoint: .bottomTrailing)
            LinearGradient(colors: [.white.opacity(dark ? 0.1 : 0.25), .clear, .black.opacity(0.12), .clear],
                           startPoint: .leading, endPoint: .trailing)
                .rotationEffect(.degrees(18 + phase * 12))
                .scaleEffect(1.6)
                .blendMode(.overlay)
        }
        .accessibilityHidden(true)
    }
}

// The refraction along the seam. Narrow, and the only colour on the whole face.
struct PrismSeam: View {
    let phase: Double

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let drift = (phase - 0.5) * size.height * 0.06
            let seam = Path { path in
                path.move(to: CGPoint(x: -10, y: size.height * 0.62 + drift))
                path.addCurve(to: CGPoint(x: size.width + 10, y: size.height * 0.38 + drift),
                              control1: CGPoint(x: size.width * 0.32, y: size.height * 0.86 + drift),
                              control2: CGPoint(x: size.width * 0.68, y: size.height * 0.14 + drift))
            }
            let prism = LinearGradient(
                colors: [Color(hue: 0.08, saturation: 0.5, brightness: 1),
                         Color(hue: 0.16, saturation: 0.45, brightness: 1),
                         Color(hue: 0.45, saturation: 0.45, brightness: 1),
                         Color(hue: 0.58, saturation: 0.5, brightness: 1),
                         Color(hue: 0.78, saturation: 0.45, brightness: 1)],
                startPoint: .leading, endPoint: .trailing
            )
            ZStack {
                seam.stroke(prism, lineWidth: 7).blur(radius: 8).opacity(0.3)
                seam.stroke(prism, lineWidth: 1.2).blur(radius: 0.8).opacity(0.7)
            }
            .blendMode(.plusLighter)
        }
        .accessibilityHidden(true)
    }
}

// Film grain: one tiny random-noise tile, made once and tiled across the card.
let grain = tile(size: 96) { _, _ in UInt8.random(in: 0...255) }

private func tile(size: Int, pixel: (Int, Int) -> UInt8) -> Image {
    let pixels = (0..<size * size).map { pixel($0 % size, $0 / size) }
    let provider = CGDataProvider(data: Data(pixels) as CFData)!
    let cgImage = CGImage(
        width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: size,
        space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
        provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
    )!
    return Image(decorative: cgImage, scale: 1)
}

// A rolled-in, bead-blasted finish: fine even grain rather than directional scratches, under a
// broad sweep of light. One noise tile and a few gradients, so it is cheap to draw and cheap to
// animate; nothing here is blurred or sampled per frame.
// Animatable so the light follows the throw and spring-back, not just their endpoints.
@Animatable
struct BeadBlastSteel: View {
    var tilt: CGSize = .zero
    var lightOffset: CGSize = .zero
    @AnimatableIgnored var warm: Color = .orange
    @AnimatableIgnored var cool: Color = .blue

    var body: some View {
        GeometryReader { geometry in
            // A virtual overhead source: moving up into it concentrates its reflection.
            // Normalize by the card size so the response holds across phone sizes.
            let x = max(-1, min(1, lightOffset.width / max(1, geometry.size.width)))
            let y = max(-1, min(1, lightOffset.height / max(1, geometry.size.height * 0.65)))
            let exposure = smoothstep(-y)
            let lift = min(1, hypot(tilt.width, tilt.height) / 9)
            let hard = max(exposure, min(1, max(0, (hypot(tilt.width, tilt.height) - 6) / 4)))
            let focus = UnitPoint(x: 0.5 - x * 0.32 + tilt.width * 0.012,
                                  y: 0.18 - y * 0.22 + tilt.height * 0.012)
            ZStack {
                LinearGradient(stops: [
                    .init(color: Color(white: 0.88), location: 0),
                    .init(color: Color(white: 0.79), location: 0.35),
                    .init(color: Color(white: 0.66), location: 0.62),
                    .init(color: Color(white: 0.74), location: 0.85),
                    .init(color: Color(white: 0.58), location: 1),
                ], startPoint: .topLeading, endPoint: .bottomTrailing)

                // The blast. Barely there, and the same in every direction.
                grain.resizable(resizingMode: .tile)
                    .opacity(0.13)
                    .blendMode(.overlay)

                // Light landing on the sheet, warm from one side and cool from the other. Turning
                // the phone does not only move them: it opens them up, so each finish shows its
                // own colour when you catch it against the light.
                RadialGradient(colors: [warm.opacity(0.4 + lift * 0.45), .clear],
                               center: .init(x: 0.12 + tilt.width * 0.016, y: 0.1 + tilt.height * 0.016),
                               startRadius: 0, endRadius: 320 + lift * 90)
                    .blendMode(.plusLighter)
                RadialGradient(colors: [cool.opacity(0.32 + lift * 0.4), .clear],
                               center: .init(x: 0.9 - tilt.width * 0.016, y: 0.82 - tilt.height * 0.016),
                               startRadius: 0, endRadius: 300 + lift * 90)
                    .blendMode(.plusLighter)

                // The shoulder of white that slides across as you turn it, hardening with the angle
                // and splitting faintly into warm and cool at its edges, the way light does coming
                // off a polished surface. At rest the split is zero and this is plain white.
                let split = lift * 0.12
                LinearGradient(stops: [.init(color: .clear, location: 0.18),
                                       .init(color: Color(hue: 0.08, saturation: split * 2.4, brightness: 1).opacity(0.3 + hard * 0.2), location: 0.36 + hard * 0.045),
                                       .init(color: .white.opacity(0.5 + hard * 0.3), location: 0.44),
                                       .init(color: Color(hue: 0.55, saturation: split * 2.4, brightness: 1).opacity(0.22 + hard * 0.16), location: 0.52 - hard * 0.045),
                                       .init(color: .white.opacity(0.08), location: 0.6),
                                       .init(color: .black.opacity(0.14), location: 1)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .offset(x: tilt.width * 5 - x * geometry.size.width * 0.12,
                            y: tilt.height * 5 - y * geometry.size.height * 0.12)
                    .blendMode(.overlay)

                // A small bright core with a softer shoulder; stronger contrast makes it read
                // as a harsh reflection rather than turning the entire sheet white.
                // Only built while it shows: at rest and face on it is not in the tree at all.
                let core = max(exposure, lift * 0.65)
                if core > 0 {
                    RadialGradient(stops: [
                        .init(color: .white.opacity(0.12 + hard * 0.48), location: 0),
                        .init(color: .white.opacity(0.06 + hard * 0.18), location: 0.22),
                        .init(color: .clear, location: 1)
                    ], center: focus, startRadius: 0,
                       endRadius: geometry.size.width * (0.85 - hard * 0.5))
                        .blendMode(.plusLighter)
                        .opacity(core)
                }

                // A narrow alignment with the overhead source, well beyond an ordinary
                // drag. Use unclamped travel so the coloured shine fades again as the card exits.
                // The finish's own hues, richer at the sweet spot, with a soft falloff.
                let travel = -lightOffset.height / max(1, geometry.size.height)
                let alignment = travel + tilt.height * 0.008 + x * 0.035
                let shine = smoothstep(1 - abs(alignment - 0.8) / 0.13)
                if shine > 0 {
                    let drift = -x * 0.18 + tilt.width * 0.008
                    let height = 0.72 + tilt.height * 0.003
                    ZStack {
                        RadialGradient(colors: [warm, warm.opacity(0.55), .clear],
                                       center: UnitPoint(x: 0.28 + drift, y: height - 0.08),
                                       startRadius: 0, endRadius: geometry.size.width * 0.75)
                        RadialGradient(colors: [cool, cool.opacity(0.5), .clear],
                                       center: UnitPoint(x: 0.78 + drift, y: height + 0.08),
                                       startRadius: 0, endRadius: geometry.size.width * 0.65)
                    }
                    .saturation(2)
                    .blendMode(.overlay)
                    .opacity(shine * 0.8)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// Eases 0...1 in and out, so a light arrives and leaves softly rather than at a hard edge.
private func smoothstep(_ t: CGFloat) -> CGFloat {
    let t = min(1, max(0, t))
    return t * t * (3 - 2 * t)
}

extension EnvironmentValues {
    // Translation through the deck's virtual light, independent of the UV reveal and tilt.
    @Entry var cardLightOffset: CGSize = .zero
    // The tilt a card should draw itself at. The deck hands the live value to the card on top
    // and zero to the ones behind, so a motion tick redraws one card instead of five.
    @Entry var cardTilt: CGSize = .zero
    // How much of the card's security printing is showing. The deck raises it as a card is
    // thrown, so a hard swipe flashes what a tilt would otherwise have to reveal.
    @Entry var cardReveal: Double = 0
}
