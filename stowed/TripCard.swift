import SwiftUI

// A playing card (decisions 20, 21): one deep colour from a curated palette, darker toward the
// edges, grain heaviest in the middle, its own texture and a double rule, a foil frame, the initial
// and suit in two corners, a monogram watermark, no emoji.
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
            RoundedRectangle(cornerRadius: 28).fill(palette.frameGradient)
            CardBorderMotif(trip: trip).padding(3)
            art.clipShape(RoundedRectangle(cornerRadius: 16)).padding(21)
            // Double hairline rule just inside the frame.
            RoundedRectangle(cornerRadius: 13).strokeBorder(.white.opacity(0.25), lineWidth: 1).padding(27)

            // Monogram watermark.
            Text(trip.initial)
                .font(.system(size: 220, weight: .bold, design: .serif))
                .opacity(0.1)
                .accessibilityHidden(true)

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
            .padding(.horizontal, 44)
            .padding(.vertical, 40)

            cornerMark
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            cornerMark
                .rotationEffect(.degrees(180))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.25), radius: 1)
        .aspectRatio(0.72, contentMode: .fit)
        .shadow(color: .black.opacity(0.18), radius: 10, y: 6)
        .accessibilityElement(children: .combine)
    }

    // Single hue radial, the trip's texture, a sheen that follows the tilt, a faint shimmer,
    // then grain masked so it is heaviest in the middle.
    private var art: some View {
        ZStack {
            RadialGradient(colors: [palette.centre, palette.edge], center: .center, startRadius: 0, endRadius: 440)
            CardTextureView(trip: trip)
            RadialGradient(colors: [.white.opacity(0.16), .clear], center: .topLeading, startRadius: 0, endRadius: 360)
                .offset(tilt)
            LinearGradient(
                stops: [.init(color: .clear, location: 0.35), .init(color: .white.opacity(0.1), location: 0.5), .init(color: .clear, location: 0.65)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .offset(x: tilt.width * 3, y: tilt.height * 3)
            // Holographic band: a spectrum sweep that rides the tilt, only with the motion effect.
            if holographic {
                LinearGradient(colors: [.red, .yellow, .green, .cyan, .blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .mask(
                        LinearGradient(stops: [.init(color: .clear, location: 0.3), .init(color: .white, location: 0.5), .init(color: .clear, location: 0.7)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                        .offset(x: tilt.width * 8, y: tilt.height * 8)
                    )
                    .opacity(0.35)
                    .blendMode(.overlay)
            }
            grain.resizable(resizingMode: .tile)
                .opacity(0.3)
                .blendMode(.overlay)
                .mask(RadialGradient(colors: [.white, .white.opacity(0.1)], center: .center, startRadius: 30, endRadius: 380))
        }
    }

    private var cornerMark: some View {
        VStack(spacing: 2) {
            Text(trip.initial).font(.system(.title2, design: .serif, weight: .bold))
            Text(trip.cardSuit.glyph).font(.footnote)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 42)
    }
}

// Film grain: one tiny random-noise tile, made once and tiled across the card.
private let grain = tile(size: 96) { _, _ in UInt8.random(in: 0...255) }

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


// The border pattern: whatever the trip has most of, alternating with its suit, walked around
// the frame. Drained of its own colour and blended in, so it reads as pressed into the frame
// rather than stuck on top of it.
private struct CardBorderMotif: View {
    let trip: Trip

    private var glyphs: [String] {
        guard let signature = trip.signatureEmoji else { return [trip.cardSuit.glyph] }
        return [signature, trip.cardSuit.glyph]
    }

    var body: some View {
        Canvas { context, size in
            let band: CGFloat = 10
            let step: CGFloat = 21
            let resolved = glyphs.map { context.resolve(Text($0).font(.system(size: 11))) }
            for (index, point) in perimeter(size: size, band: band, step: step).enumerated() {
                context.draw(resolved[index % resolved.count], at: point, anchor: .center)
            }
        }
        .saturation(0)
        .opacity(0.4)
        .blendMode(.overlay)
        .accessibilityHidden(true)
    }

    // Evenly spaced points clockwise from the top-left corner, along the middle of the band.
    private func perimeter(size: CGSize, band: CGFloat, step: CGFloat) -> [CGPoint] {
        let left = band, right = size.width - band
        let top = band, bottom = size.height - band
        var points: [CGPoint] = []
        var x = left
        while x <= right { points.append(CGPoint(x: x, y: top)); x += step }
        var y = top + step
        while y <= bottom { points.append(CGPoint(x: right, y: y)); y += step }
        x = right - step
        while x >= left { points.append(CGPoint(x: x, y: bottom)); x -= step }
        y = bottom - step
        while y > top { points.append(CGPoint(x: left, y: y)); y -= step }
        return points
    }
}
