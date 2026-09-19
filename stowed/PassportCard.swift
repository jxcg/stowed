import SwiftUI

// A second way to draw a trip (decision 30): a neon passport page instead of a playing card.
// Same data, no new model fields. Deep ground, two fluorescent inks taken from the trip's own
// hue, a halftone globe with its flight arcs, and a machine-readable strip along the bottom.
struct PassportCard: View {
    let trip: Trip
    var tilt: CGSize = .zero
    var holographic = false

    private var ink: PassportInk { PassportInk(hue: trip.cardPalette.hue) }

    private var days: Int? {
        guard let start = trip.startDate, let end = trip.endDate else { return nil }
        return max(1, Calendar.current.dateComponents([.day], from: start, to: end).day ?? 1)
    }

    // First ten distinct emoji, in packing order. The passport's answer to a row of flags.
    private var chips: [String] {
        var seen = Set<String>()
        return Array(trip.items.sorted { $0.addedAt < $1.addedAt }.map(\.emoji).filter { seen.insert($0).inserted }.prefix(10))
    }

    var body: some View {
        VStack(spacing: 0) {
            GlyphStrip(ink: ink, initial: trip.initial)
            FlightMap(trip: trip, ink: ink)
                .frame(maxHeight: .infinity)
            if !chips.isEmpty { chipRow }
            dashedRule
            details
            MachineReadableStrip(trip: trip, ink: ink)
        }
        .background(ink.ground)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(ink.glow.opacity(0.45), lineWidth: 1))
        .aspectRatio(0.72, contentMode: .fit)
        .shadow(color: ink.glow.opacity(0.5), radius: 16, y: 8)
        .rotation3DEffect(.degrees(-tilt.height * 0.35), axis: (x: 1, y: 0, z: 0))
        .rotation3DEffect(.degrees(tilt.width * 0.35), axis: (x: 0, y: 1, z: 0))
        .accessibilityElement(children: .combine)
    }

    private var chipRow: some View {
        HStack(spacing: -5) {
            ForEach(Array(chips.enumerated()), id: \.offset) { _, emoji in
                Text(emoji)
                    .font(.system(size: 13))
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(ink.haze))
                    .overlay(Circle().strokeBorder(ink.glow.opacity(0.6), lineWidth: 0.8))
            }
        }
        .padding(.vertical, 10)
        .accessibilityHidden(true)
    }

    private var dashedRule: some View {
        Rectangle()
            .fill(ink.glow.opacity(0.35))
            .frame(height: 1)
            .padding(.horizontal, 14)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(trip.name.uppercased())
                .font(.system(size: 21, weight: .semibold))
                .tracking(0.5)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("PASSPORT · PASS · PASAPORTE")
                .font(.system(size: 8, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(ink.glow2)

            HStack(alignment: .top, spacing: 18) {
                stat("BAGS", "\(trip.bags.count)")
                stat("ITEMS", "\(trip.items.count)")
                if let days { stat("DAYS", "\(days)") }
                Spacer(minLength: 0)
                if trip.hasStartedReturn {
                    stat("HOME", "\(trip.returnConfirmedCount)", of: trip.returnExpected.count)
                }
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func stat(_ label: String, _ value: String, of total: Int? = nil) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .tracking(1.1)
                .foregroundStyle(ink.glow2)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value).font(.system(size: 26, weight: .bold)).monospacedDigit()
                if let total {
                    Text("/\(total)").font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }
}

// The fluorescent inks. Every passport stays in the violet-magenta-cyan family however the
// trip's own hue falls, because that family is the whole point of the style; the trip only
// decides where within it this card sits.
struct PassportInk {
    let hue: Double

    private func within(_ lower: Double, _ upper: Double) -> Double { lower + hue * (upper - lower) }

    var ground: LinearGradient {
        LinearGradient(colors: [Color(hue: within(0.70, 0.79), saturation: 0.88, brightness: 0.42),
                                Color(hue: within(0.72, 0.83), saturation: 1, brightness: 0.2)],
                       startPoint: .top, endPoint: .bottom)
    }
    // Primary ink: violet through to hot magenta.
    var glow: Color { Color(hue: within(0.76, 0.93), saturation: 0.85, brightness: 1) }
    // Secondary ink: always on the cyan side, so the two never muddy each other.
    var glow2: Color { Color(hue: within(0.46, 0.55), saturation: 0.8, brightness: 1) }
    var haze: Color { Color(hue: within(0.72, 0.82), saturation: 0.85, brightness: 0.5) }
}

// The repeating strip of planes and the trip's letter that runs along the top edge.
private struct GlyphStrip: View {
    let ink: PassportInk
    let initial: String

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 10) {
                ForEach(0..<Int(geometry.size.width / 30) + 1, id: \.self) { index in
                    if index.isMultiple(of: 5) {
                        Text(initial).font(.system(size: 13, weight: .heavy)).foregroundStyle(ink.glow)
                    } else {
                        Image(systemName: "airplane")
                            .font(.system(size: 11))
                            .foregroundStyle(index.isMultiple(of: 2) ? ink.glow2.opacity(0.75) : ink.glow.opacity(0.5))
                    }
                }
            }
            .frame(width: geometry.size.width, alignment: .leading)
        }
        .frame(height: 26)
        .padding(.horizontal, 12)
        .accessibilityHidden(true)
    }
}

// A halftone globe with the trip's own flight paths arcing over it. The dots are a grid masked
// by a system globe, so there is no map asset to ship.
private struct FlightMap: View {
    let trip: Trip
    let ink: PassportInk

    var body: some View {
        ZStack {
            Canvas { context, size in
                let spacing: CGFloat = 5
                let dot = CGSize(width: 2.2, height: 2.2)
                var y: CGFloat = 0
                while y < size.height {
                    var x: CGFloat = 0
                    while x < size.width {
                        context.fill(Path(ellipseIn: CGRect(origin: CGPoint(x: x, y: y), size: dot)), with: .color(ink.glow))
                        x += spacing
                    }
                    y += spacing
                }
            }
            .mask(
                Image(systemName: "globe.europe.africa.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, 2)
            )
            .opacity(0.9)

            Canvas { context, size in
                var random = SeededRandom(seed: trip.textureSeed)
                let hub = CGPoint(x: size.width * (0.35 + random.unit() * 0.3), y: size.height * (0.3 + random.unit() * 0.2))
                for _ in 0..<5 {
                    let destination = CGPoint(x: size.width * (0.1 + random.unit() * 0.8),
                                              y: size.height * (0.15 + random.unit() * 0.7))
                    var path = Path()
                    path.move(to: hub)
                    let lift = min(hub.y, destination.y) - size.height * (0.1 + random.unit() * 0.2)
                    path.addQuadCurve(to: destination, control: CGPoint(x: (hub.x + destination.x) / 2, y: lift))
                    context.stroke(path, with: .color(ink.glow2.opacity(0.35)), lineWidth: 2.5)
                    context.stroke(path, with: .color(.white.opacity(0.9)), lineWidth: 1)
                    context.fill(Path(ellipseIn: CGRect(x: destination.x - 2.5, y: destination.y - 2.5, width: 5, height: 5)),
                                 with: .color(ink.glow2))
                }
                context.fill(Path(ellipseIn: CGRect(x: hub.x - 3.5, y: hub.y - 3.5, width: 7, height: 7)), with: .color(.white))
            }
        }
        .padding(.vertical, 6)
        .accessibilityHidden(true)
    }
}

// The strip a machine would read, if this were a real passport.
private struct MachineReadableStrip: View {
    let trip: Trip
    let ink: PassportInk

    private func line(_ text: String, width: Int) -> String {
        let cleaned = text.uppercased().replacingOccurrences(of: " ", with: "<")
        return String((cleaned + String(repeating: "<", count: width)).prefix(width))
    }

    private var dates: String {
        guard let start = trip.startDate else { return "NODATES" }
        let formatter = Date.FormatStyle(date: .numeric).year(.twoDigits).month(.twoDigits).day(.twoDigits)
        return start.formatted(formatter).replacingOccurrences(of: "/", with: "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(line("P<STW<\(trip.name)", width: 40))
            Text(line("\(dates)<<\(trip.bags.count)BAGS<\(trip.items.count)ITEMS<STOWED", width: 40))
        }
        .font(.system(size: 9, weight: .medium, design: .monospaced))
        .foregroundStyle(.white.opacity(0.85))
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(ink.haze.opacity(0.45))
        .accessibilityHidden(true)
    }
}
