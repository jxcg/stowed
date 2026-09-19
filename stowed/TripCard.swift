import SwiftUI

// A playing card (decisions 20, 21): one deep colour from a curated palette, darker toward the
// edges, a chrome face with one prismatic seam inside a hard-edged foil frame, the trip's mark punched
// out of metal, the initial and suit in two corners.
struct TripCard: View {
    let trip: Trip
    var tilt: CGSize = .zero
    var holographic = false

    private var palette: CardPalette { trip.cardPalette }

    private var dates: String? {
        guard let start = trip.startDate else { return nil }
        let range = trip.endDate.map { start..<$0 }
        return range.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? start.formatted(date: .abbreviated, time: .omitted)
    }


    var body: some View {
        ZStack {
            // The card has thickness: a darker slab sits just under the face.
            RoundedRectangle(cornerRadius: 26).fill(palette.stock).offset(y: 2.5)

            RoundedRectangle(cornerRadius: 26).fill(palette.frameGradient)
            // Rim light along the top edge, the way light catches a real card.
            RoundedRectangle(cornerRadius: 26)
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.65), .clear], startPoint: .top, endPoint: .center), lineWidth: 1)

            art
                .clipShape(RoundedRectangle(cornerRadius: 19))
                // Bevel: dark where the window is cut, light on the far side, so the face sits down inside the frame.
                .overlay(
                    RoundedRectangle(cornerRadius: 19)
                        .strokeBorder(
                            LinearGradient(colors: [.black.opacity(0.5), .black.opacity(0.1), .white.opacity(0.3)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1.5
                        )
                )
                .padding(9)

            RoundedRectangle(cornerRadius: 15).strokeBorder(.white.opacity(0.22), lineWidth: 1).padding(15)

            // The trip's mark, punched out of metal, as on the other card.
            DotMatrix(symbol: TripSymbol.forTrip(trip),
                      metal: Gradient(colors: [Color(white: 1), Color(white: 0.7), Color(white: 0.92), Color(white: 0.5)]),
                      spacing: 7, dot: 3.4)
                .padding(.horizontal, 74)
                .padding(.vertical, 96)
                .opacity(0.9)
                .shadow(color: .black.opacity(0.4), radius: 6)

            VStack(spacing: 8) {
                Text(trip.name)
                    .font(.system(.title, design: .serif, weight: .bold))
                    .multilineTextAlignment(.center)
                Text("\(trip.bags.count) bags · \(trip.items.count) items")
                    .font(.system(.footnote, design: .serif))
                    .opacity(0.8)
                Spacer()
                if trip.isReturnComplete {
                    Label("Home", systemImage: "checkmark.seal.fill").font(.footnote).accessibilityLabel("Trip complete")
                } else if trip.hasStartedReturn {
                    Text("Home \(trip.returnConfirmedCount) / \(trip.returnExpected.count)").font(.footnote).monospacedDigit()
                }
                // Small-caps footer, like a foil stamp.
                Text(dates ?? "Stowed")
                    .font(.system(.caption, design: .serif).smallCaps())
                    .tracking(3)
                    .opacity(0.85)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 36)

            cornerMark
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            cornerMark
                .rotationEffect(.degrees(180))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .foregroundStyle(.white)
        // Letterpress: everything white is cut into the surface, dark below and a hint of light above.
        .shadow(color: .black.opacity(0.55), radius: 0.5, y: 1)
        .shadow(color: .white.opacity(0.18), radius: 0.5, y: -0.5)
        .aspectRatio(0.72, contentMode: .fit)
        // A real card lying on a surface casts two shadows: a tight contact one and a soft ambient one.
        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
        .shadow(color: .black.opacity(0.2), radius: 16, y: 11)
        // With the motion effect on, the card itself turns to the light.
        .rotation3DEffect(.degrees(-tilt.height * 0.35), axis: (x: 1, y: 0, z: 0))
        .rotation3DEffect(.degrees(tilt.width * 0.35), axis: (x: 0, y: 1, z: 0))
        .accessibilityElement(children: .combine)
    }

    // Chrome with one prismatic seam, the same treatment as the card back, under the trip's
    // texture and grain. The colour now lives in the frame and the seam, not the face.
    private var art: some View {
        ZStack {
            Chrome(phase: seamPhase, dark: true)
            PrismSeam(phase: seamPhase)
            CardTextureView(trip: trip).opacity(0.3)
            RadialGradient(colors: [.white.opacity(0.14), .clear], center: .topLeading, startRadius: 0, endRadius: 360)
                .offset(tilt)
            if holographic {
                LinearGradient(colors: [.red, .yellow, .green, .cyan, .blue, .purple],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .mask(
                        LinearGradient(stops: [.init(color: .clear, location: 0.35),
                                               .init(color: .white, location: 0.5),
                                               .init(color: .clear, location: 0.65)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                        .offset(x: tilt.width * 8, y: tilt.height * 8)
                    )
                    .opacity(0.3)
                    .blendMode(.plusLighter)
            }
            grain.resizable(resizingMode: .tile)
                .opacity(0.22)
                .blendMode(.overlay)
                .mask(RadialGradient(colors: [.white, .white.opacity(0.1)], center: .center, startRadius: 30, endRadius: 380))
        }
    }

    // Fixed to the trip, so the seam lies the same way every launch.
    private var seamPhase: Double {
        Double(trip.textureSeed % 100) / 100
    }

    private var cornerMark: some View {
        VStack(spacing: 2) {
            Text(trip.initial).font(.system(.title2, design: .serif, weight: .bold))
            Text(trip.cardSuit.glyph).font(.footnote)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 32)
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
