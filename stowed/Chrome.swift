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

// Brushed metal: noise that varies across the grain but never along it, so tiling it gives
// continuous striations rather than sand. Made once.
let brushed: Image = {
    let size = 128
    let row = (0..<size).map { _ in UInt8.random(in: 96...210) }
    var pixels = [UInt8]()
    pixels.reserveCapacity(size * size)
    for _ in 0..<size { pixels.append(contentsOf: row) }
    let provider = CGDataProvider(data: Data(pixels) as CFData)!
    let cgImage = CGImage(
        width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: size,
        space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
        provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
    )!
    return Image(decorative: cgImage, scale: 1)
}()

// Brushed steel. A tonal sweep from a bright shoulder down into shadow, raked with fine
// striation, then a broad highlight across it. Neutral, and the same technique whether it is
// the surface of a card or a texture laid over one.
struct BrushedSteel: View {
    var tilt: CGSize = .zero
    var tone: Double = 1          // 1 is the full steel sheet; lower lays it over something else.
    var angle: Double = 24

    var body: some View {
        ZStack {
            LinearGradient(stops: [
                .init(color: Color(white: 0.93), location: 0),
                .init(color: Color(white: 0.74), location: 0.18),
                .init(color: Color(white: 0.86), location: 0.3),
                .init(color: Color(white: 0.52), location: 0.55),
                .init(color: Color(white: 0.63), location: 0.72),
                .init(color: Color(white: 0.34), location: 1),
            ], startPoint: .top, endPoint: .bottom)
            .opacity(tone)

            // The rake. Fine, and tight to the grain.
            brushed.resizable(resizingMode: .tile)
                .opacity(0.55)
                .blendMode(.overlay)
                .rotationEffect(.degrees(angle))
                .scaleEffect(x: 1.1, y: 2.6)
            brushed.resizable(resizingMode: .tile)
                .opacity(0.3)
                .blendMode(.softLight)
                .rotationEffect(.degrees(angle - 3))
                .scaleEffect(x: 4.5, y: 1.4)
                .blur(radius: 0.6)

            // The broad shoulder of light that makes it look turned toward you.
            LinearGradient(stops: [.init(color: .white.opacity(0.5), location: 0),
                                   .init(color: .clear, location: 0.42),
                                   .init(color: .black.opacity(0.22), location: 1)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .offset(x: tilt.width * 3, y: tilt.height * 3)
                .blendMode(.overlay)
        }
        .accessibilityHidden(true)
    }
}

// A rolled-in, bead-blasted finish: fine even grain rather than directional scratches, under a
// broad sweep of light. One noise tile and three gradients, so it is cheap to draw and cheap to
// animate; nothing here is blurred or sampled per frame.
struct BeadBlastSteel: View {
    var tilt: CGSize = .zero
    var warm: Color = .orange
    var cool: Color = .blue

    var body: some View {
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

            // Light landing on the sheet, warm from one side and cool from the other. It moves
            // with the phone, which is what makes the finish read as metal.
            RadialGradient(colors: [warm.opacity(0.4), .clear],
                           center: .init(x: 0.12 + tilt.width * 0.012, y: 0.1 + tilt.height * 0.012),
                           startRadius: 0, endRadius: 320)
                .blendMode(.plusLighter)
            RadialGradient(colors: [cool.opacity(0.32), .clear],
                           center: .init(x: 0.9 - tilt.width * 0.012, y: 0.82 - tilt.height * 0.012),
                           startRadius: 0, endRadius: 300)
                .blendMode(.plusLighter)

            // The shoulder of white that slides across as you turn it.
            LinearGradient(stops: [.init(color: .clear, location: 0.18),
                                   .init(color: .white.opacity(0.5), location: 0.44),
                                   .init(color: .white.opacity(0.08), location: 0.56),
                                   .init(color: .black.opacity(0.14), location: 1)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .offset(x: tilt.width * 5, y: tilt.height * 5)
                .blendMode(.overlay)
        }
        .accessibilityHidden(true)
    }
}

// How much of the card's security printing is showing. The deck raises it as a card is thrown,
// so a hard swipe flashes what a tilt would otherwise have to reveal.
private struct CardRevealKey: EnvironmentKey {
    static let defaultValue: Double = 0
}

extension EnvironmentValues {
    var cardReveal: Double {
        get { self[CardRevealKey.self] }
        set { self[CardRevealKey.self] = newValue }
    }
}
