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
