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
            CardBorderMotif(trip: trip)
            art.clipShape(RoundedRectangle(cornerRadius: 18)).padding(12)
            // Double hairline rule just inside the frame.
            RoundedRectangle(cornerRadius: 15).strokeBorder(.white.opacity(0.22), lineWidth: 1).padding(17)

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
        .padding(.horizontal, 30)
        .padding(.vertical, 32)
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


// The border pattern: a run of small abstract marks in the slim band around the frame. Which
// mark you get follows the trip's suit, so every card's edge belongs to it. Drawn in the
// frame's own light rather than a colour of its own.
private struct CardBorderMotif: View {
    let trip: Trip

    // Local coordinates: centred on the origin, running along +x with the edge.
    private var mark: (step: CGFloat, path: Path, filled: Bool) {
        switch trip.cardSuit {
        case .spade:                                  // chevrons
            (9, Path { $0.move(to: CGPoint(x: -2, y: -2.4)); $0.addLine(to: CGPoint(x: 1.2, y: 0)); $0.addLine(to: CGPoint(x: -2, y: 2.4)) }, false)
        case .heart:                                  // beads
            (8, Path(ellipseIn: CGRect(x: -1.7, y: -1.7, width: 3.4, height: 3.4)), true)
        case .diamond:                                // lozenges
            (10, Path { $0.move(to: CGPoint(x: -2.6, y: 0)); $0.addLine(to: CGPoint(x: 0, y: -2.4)); $0.addLine(to: CGPoint(x: 2.6, y: 0)); $0.addLine(to: CGPoint(x: 0, y: 2.4)); $0.closeSubpath() }, true)
        case .club:                                   // ticks
            (7, Path { $0.move(to: CGPoint(x: 0, y: -2.6)); $0.addLine(to: CGPoint(x: 0, y: 2.6)) }, false)
        }
    }

    var body: some View {
        Canvas { context, size in
            let (step, path, filled) = mark
            let ink = GraphicsContext.Shading.color(.white)
            for (point, angle) in perimeter(size: size, band: 6, step: step) {
                var layer = context
                layer.translateBy(x: point.x, y: point.y)
                layer.rotate(by: angle)
                if filled {
                    layer.fill(path, with: ink)
                } else {
                    layer.stroke(path, with: ink, lineWidth: 1.3)
                }
            }
        }
        .opacity(0.45)
        .blendMode(.overlay)
        .accessibilityHidden(true)
    }

    // Points clockwise from the top-left, each with the direction of the edge it sits on.
    private func perimeter(size: CGSize, band: CGFloat, step: CGFloat) -> [(CGPoint, Angle)] {
        let left = band, right = size.width - band
        let top = band, bottom = size.height - band
        var marks: [(CGPoint, Angle)] = []
        var x = left
        while x <= right { marks.append((CGPoint(x: x, y: top), .zero)); x += step }
        var y = top + step
        while y <= bottom { marks.append((CGPoint(x: right, y: y), .degrees(90))); y += step }
        x = right - step
        while x >= left { marks.append((CGPoint(x: x, y: bottom), .degrees(180))); x -= step }
        y = bottom - step
        while y > top { marks.append((CGPoint(x: left, y: y), .degrees(270))); y -= step }
        return marks
    }
}
