import SwiftUI

// Procedural texture under the grain (decision 24). Drawn from the trip's own initial, dates
// and name. Seeded from the trip so a card looks the same every launch.
enum CardTexture: String, CaseIterable {
    case scatter, lattice, stamp
}

struct CardTextureView: View {
    let trip: Trip

    // Digits of the dates, or of the creation date when the trip has none.
    private var digits: [String] {
        let date = trip.startDate ?? trip.createdAt
        let parts = Calendar.current.dateComponents([.day, .month, .year], from: date)
        return "\(parts.day ?? 1)\(parts.month ?? 1)\(parts.year ?? 2026)".map(String.init)
    }

    private var stampText: String {
        let dates = trip.startDate.map { $0.formatted(.dateTime.day().month(.abbreviated).year()) } ?? "no dates"
        return "\(trip.name)  ·  \(dates)  ·  STOWED  ·  ".uppercased()
    }

    var body: some View {
        Canvas { context, size in
            var random = SeededRandom(seed: trip.textureSeed)
            switch trip.cardTexture {
            case .scatter: drawScatter(&context, size, &random)
            case .lattice: drawLattice(&context, size)
            case .stamp: drawStamp(&context, size)
            }
        }
        .foregroundStyle(.white)
        .blendMode(.overlay)
        .accessibilityHidden(true)
    }

    // Initial and date digits thrown across the face at random sizes and angles.
    private func drawScatter(_ context: inout GraphicsContext, _ size: CGSize, _ random: inout SeededRandom) {
        let glyphs = [trip.initial, trip.initial] + digits
        for _ in 0..<48 {
            let glyph = glyphs[Int(random.next() % UInt64(glyphs.count))]
            let point = CGPoint(x: random.unit() * size.width, y: random.unit() * size.height)
            let fontSize = 26 + random.unit() * 70
            let angle = Angle.degrees(random.unit() * 80 - 40)
            var layer = context
            layer.translateBy(x: point.x, y: point.y)
            layer.rotate(by: angle)
            layer.opacity = 0.16 + random.unit() * 0.2
            layer.draw(Text(glyph).font(.system(size: fontSize, weight: .bold, design: .serif)), at: .zero)
        }
    }

    // The initial on a diagonal grid, small and regular.
    private func drawLattice(_ context: inout GraphicsContext, _ size: CGSize) {
        let step: CGFloat = 40
        let text = context.resolve(Text(trip.initial).font(.system(size: 16, weight: .bold, design: .serif)))
        var row = 0
        var y: CGFloat = 0
        while y < size.height + step {
            let shift = row.isMultiple(of: 2) ? 0 : step / 2
            var x: CGFloat = shift
            while x < size.width + step {
                var layer = context
                layer.opacity = 0.45
                layer.draw(text, at: CGPoint(x: x, y: y))
                x += step
            }
            y += step * 0.75
            row += 1
        }
    }

    // Name, dates and STOWED repeated along all four inner edges, like a coin edge.
    private func drawStamp(_ context: inout GraphicsContext, _ size: CGSize) {
        let inset: CGFloat = 27
        let text = context.resolve(Text(stampText).font(.system(size: 9, weight: .medium, design: .serif)).tracking(2))
        let unit = text.measure(in: CGSize(width: 10_000, height: 20)).width
        let edges: [(CGPoint, Angle, CGFloat)] = [
            (CGPoint(x: inset, y: inset), .zero, size.width - inset * 2),
            (CGPoint(x: size.width - inset, y: inset), .degrees(90), size.height - inset * 2),
            (CGPoint(x: size.width - inset, y: size.height - inset), .degrees(180), size.width - inset * 2),
            (CGPoint(x: inset, y: size.height - inset), .degrees(270), size.height - inset * 2),
        ]
        for (origin, angle, length) in edges {
            var layer = context
            layer.translateBy(x: origin.x, y: origin.y)
            layer.rotate(by: angle)
            layer.clip(to: Path(CGRect(x: 0, y: -10, width: length, height: 20)))
            layer.opacity = 0.6
            var x: CGFloat = 0
            while x < length {
                layer.draw(text, at: CGPoint(x: x, y: 0), anchor: .leading)
                x += unit
            }
        }
    }
}

// SplitMix64. Tiny, deterministic, good enough for scattering glyphs.
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    // 0..<1
    mutating func unit() -> CGFloat { CGFloat(next() >> 11) / CGFloat(1 << 53) }
}
