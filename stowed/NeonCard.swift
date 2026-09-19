import SwiftUI

// The second way to draw a trip (decision 30): a lit sign rather than a playing card. Deep
// ground, two bright inks, and the trip's own letter punched out of a dot matrix. Ten
// colourways, one per palette, all built the same way. Same data, no new model fields.
struct NeonCard: View {
    let trip: Trip
    var tilt: CGSize = .zero
    var holographic = false
    @Environment(\.colorScheme) private var scheme

    private var ink: NeonInk { NeonInk(accent: trip.cardPalette.neonAccent, dark: scheme == .dark) }

    private var days: Int? {
        guard let start = trip.startDate, let end = trip.endDate else { return nil }
        return max(1, Calendar.current.dateComponents([.day], from: start, to: end).day ?? 1)
    }

    // First ten distinct emoji, in packing order.
    private var chips: [String] {
        var seen = Set<String>()
        return Array(trip.items.sorted { $0.addedAt < $1.addedAt }.map(\.emoji).filter { seen.insert($0).inserted }.prefix(10))
    }

    private var dateLine: String {
        guard let start = trip.startDate else { return "NO DATES" }
        return start.formatted(.dateTime.day().month(.abbreviated).year()).uppercased()
    }

    private var dark: Bool { scheme == .dark }

    // How hard the light is hitting it. Nothing at rest, full at a good tilt.
    private var ultraviolet: Double {
        guard holographic else { return 0 }
        return min(1, hypot(tilt.width, tilt.height) / 9)
    }

    var body: some View {
        VStack(spacing: 0) {
            TickStrip(ink: ink)
            DotMatrixMark(trip: trip, ink: ink)
                .frame(maxHeight: .infinity)
            if !chips.isEmpty { chipRow }
            Rectangle().fill(ink.glow.opacity(0.35)).frame(height: 1).padding(.horizontal, 14)
            details
            footer
        }
        .background(backdrop)
        // Tilt it under the light and the security printing answers, the way a banknote does,
        // with a slick of spectrum across it like the holographic patch on the same note.
        .overlay(UltravioletLayer(trip: trip, ink: ink, strength: ultraviolet))
        .overlay {
            if holographic {
                LinearGradient(colors: [.red, .yellow, .green, .cyan, .blue, .purple],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .mask(
                        LinearGradient(stops: [.init(color: .clear, location: 0.28),
                                               .init(color: .white, location: 0.5),
                                               .init(color: .clear, location: 0.72)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                        .offset(x: tilt.width * 9, y: tilt.height * 9)
                    )
                    .opacity(0.28)
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(ink.rim, lineWidth: 4))
        // A fine grain along the rim. Close enough to read as texture rather than a pattern.
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color.white.opacity(dark ? 0.1 : 0.2), style: StrokeStyle(lineWidth: 4, dash: [1.5, 2.5]))
        )
        .aspectRatio(0.72, contentMode: .fit)
        .shadow(color: ink.glow.opacity(0.2), radius: 10, y: 6)
        .rotation3DEffect(.degrees(-tilt.height * 0.35), axis: (x: 1, y: 0, z: 0))
        .rotation3DEffect(.degrees(tilt.width * 0.35), axis: (x: 0, y: 1, z: 0))
        .accessibilityElement(children: .combine)
    }

    // The ground is not just a gradient: colour thrown in from the other mode's base, the
    // place's own letter standing behind everything, and grain over the lot.
    private var backdrop: some View {
        ZStack {
            ink.ground
            Splashes(trip: trip, ink: ink)
            MonogramField(initial: trip.initial, ink: ink)
            grain.resizable(resizingMode: .tile)
                .opacity(dark ? 0.22 : 0.3)
                .blendMode(dark ? .overlay : .multiply)
        }
        .accessibilityHidden(true)
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

    private var details: some View {
        VStack(alignment: .leading, spacing: 10) {
            // SF Extended: the wide cut, so the place name carries the card.
            Text(trip.name.uppercased())
                .font(.system(size: 22, weight: .semibold).width(.expanded))
                .lineLimit(1)
                .minimumScaleFactor(0.5)

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
        .foregroundStyle(ink.text)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private func stat(_ label: String, _ value: String, of total: Int? = nil) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 8, weight: .medium).width(.expanded))
                .foregroundStyle(ink.glow2)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value).font(.system(size: 26, weight: .bold)).monospacedDigit()
                if let total {
                    Text("/\(total)").font(.system(size: 13, weight: .medium)).foregroundStyle(ink.text.opacity(0.7))
                }
            }
        }
    }

    private var footer: some View {
        Text(dateLine)
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .tracking(2)
            .foregroundStyle(ink.text.opacity(0.85))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 22)
            .padding(.bottom, 14)
            // Fades up into the card instead of sitting on a hard band.
            .background(
                LinearGradient(colors: [ink.haze.opacity(0), ink.haze.opacity(0.5)],
                               startPoint: .top, endPoint: .bottom)
            )
    }
}

// One base, two modes (decision 30). The ground is the same on every card: pale blue into
// lavender by day, deep indigo by night. Only the accent moves from trip to trip, and it never
// leaves the band between cyan and magenta, so a wall of these still looks like one set.
struct NeonInk {
    let accent: Double
    let dark: Bool

    private func shifted(_ amount: Double) -> Double { (accent + amount + 1).truncatingRemainder(dividingBy: 1) }

    var ground: LinearGradient {
        let stops: [Color] = dark
            ? [Color(hue: 0.70, saturation: 0.78, brightness: 0.46), Color(hue: 0.73, saturation: 0.94, brightness: 0.2)]
            : [Color(hue: 0.57, saturation: 0.16, brightness: 1), Color(hue: 0.74, saturation: 0.22, brightness: 0.94)]
        return LinearGradient(colors: stops, startPoint: .top, endPoint: .bottom)
    }

    // The bright ink. Turned down by day so it still reads against a pale ground.
    var glow: Color { Color(hue: accent, saturation: dark ? 0.8 : 0.9, brightness: dark ? 1 : 0.74) }
    // The pale ink, a step along from the first.
    var glow2: Color { Color(hue: shifted(0.05), saturation: dark ? 0.32 : 0.7, brightness: dark ? 1 : 0.62) }
    var haze: Color { Color(hue: shifted(-0.02), saturation: dark ? 0.85 : 0.3, brightness: dark ? 0.5 : 0.9) }
    // Everything written on the card.
    var text: Color { dark ? .white : Color(hue: 0.73, saturation: 0.85, brightness: 0.34) }
    // Colour borrowed from the other mode, thrown across the ground so it is never flat.
    var splash: Color {
        dark ? Color(hue: 0.57, saturation: 0.4, brightness: 1) : Color(hue: 0.72, saturation: 0.9, brightness: 0.5)
    }
    // The rim runs from the accent into its deepened neighbour. Neighbours sit together.
    var rim: LinearGradient {
        LinearGradient(colors: [Color(hue: accent, saturation: dark ? 0.42 : 0.5, brightness: dark ? 0.82 : 0.9),
                                Color(hue: shifted(-0.09), saturation: dark ? 0.8 : 0.7, brightness: dark ? 0.46 : 0.68)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// A thin run of ticks along the top edge, alternating between the two inks.
private struct TickStrip: View {
    let ink: NeonInk

    var body: some View {
        Canvas { context, size in
            var x: CGFloat = 0
            var index = 0
            while x < size.width {
                let tall = index.isMultiple(of: 4)
                let height: CGFloat = tall ? 10 : 5
                context.fill(Path(CGRect(x: x, y: (size.height - height) / 2, width: 2, height: height)),
                             with: .color(tall ? ink.glow : ink.glow2.opacity(0.7)))
                x += 7
                index += 1
            }
        }
        .frame(height: 16)
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .accessibilityHidden(true)
    }
}

// A map pin punched out of a field of dots. The same mark on every card; what tells them apart
// is the letter tiled behind and the accent.
private struct DotMatrixMark: View {
    let trip: Trip
    let ink: NeonInk

    var body: some View {
        GeometryReader { geometry in
            dots
                .mask(shape(in: geometry.size))
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .accessibilityHidden(true)
    }

    private var dots: some View {
        Canvas { context, size in
            let spacing: CGFloat = 6
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    // Brighter toward the top, so the matrix reads as lit rather than printed.
                    let lift = 1 - (y / size.height) * 0.45
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2.8, height: 2.8)),
                                 with: .color(ink.glow.opacity(lift)))
                    x += spacing
                }
                y += spacing
            }
        }
    }

    private func shape(in size: CGSize) -> some View {
        Image(systemName: "mappin.and.ellipse")
            .resizable()
            .scaledToFit()
            .frame(width: size.width, height: size.height)
    }
}

// What the card hides until light of the right kind falls on it: fibres through the stock, a
// thread down one side, and the trip's own letter watermarked across the middle. Only drawn
// while the motion effect is on and the phone is actually tilted.
private struct UltravioletLayer: View {
    let trip: Trip
    let ink: NeonInk
    let strength: Double

    private var fluorescence: Color { ink.glow2 }

    var body: some View {
        Canvas { context, size in
            var random = SeededRandom(seed: trip.textureSeed)

            // Fibres, scattered through the stock at every angle.
            for _ in 0..<70 {
                let origin = CGPoint(x: random.unit() * size.width, y: random.unit() * size.height)
                let angle = random.unit() * 2 * .pi
                let length = 6 + random.unit() * 12
                var fibre = Path()
                fibre.move(to: origin)
                fibre.addLine(to: CGPoint(x: origin.x + cos(angle) * length, y: origin.y + sin(angle) * length))
                let tint = random.unit() > 0.5 ? ink.text : fluorescence
                context.stroke(fibre, with: .color(tint.opacity(0.55 + random.unit() * 0.45)), lineWidth: 1.1)
            }

            // The thread, dashed, running the height of the card.
            let threadX = size.width * 0.82
            var thread = Path()
            thread.move(to: CGPoint(x: threadX, y: 0))
            thread.addLine(to: CGPoint(x: threadX, y: size.height))
            context.stroke(thread, with: .color(fluorescence.opacity(0.7)),
                           style: StrokeStyle(lineWidth: 3, dash: [9, 5]))

            // The watermark, only readable under the light.
            let mark = context.resolve(
                Text(trip.initial)
                    .font(.system(size: size.height * 0.34, weight: .black).width(.expanded))
                    .foregroundStyle(fluorescence.opacity(0.5))
            )
            context.draw(mark, at: CGPoint(x: size.width / 2, y: size.height * 0.46), anchor: .center)
        }
        .blendMode(.plusLighter)
        .opacity(strength)
        .animation(.easeOut(duration: 0.15), value: strength)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// The place's letter, tiled small across the ground. Close to invisible on its own; it is there
// to stop the card reading as a flat sheet of colour.
private struct MonogramField: View {
    let initial: String
    let ink: NeonInk

    var body: some View {
        Canvas { context, size in
            let glyph = context.resolve(
                Text(initial)
                    .font(.system(size: 22, weight: .black).width(.expanded))
                    .foregroundStyle(ink.text.opacity(0.07))
            )
            let step: CGFloat = 54
            var row = 0
            var y: CGFloat = -step / 2
            while y < size.height + step {
                var x: CGFloat = row.isMultiple(of: 2) ? 0 : step / 2
                while x < size.width + step {
                    context.draw(glyph, at: CGPoint(x: x, y: y), anchor: .center)
                    x += step
                }
                y += step * 0.8
                row += 1
            }
        }
        .accessibilityHidden(true)
    }
}

// The same two colours on every card, thrown across the ground differently each time. Where
// they land and how hard they hit is fixed to the trip, so one card never looks like the next
// and the set still looks like a set.
private struct Splashes: View {
    let trip: Trip
    let ink: NeonInk

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let reach = max(size.width, size.height)
            var random = SeededRandom(seed: trip.textureSeed)
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    let colour = index == 1 ? ink.glow : ink.splash
                    let centre = UnitPoint(x: random.unit(), y: random.unit())
                    let spread = reach * (0.35 + random.unit() * 0.55)
                    let weight = 0.2 + random.unit() * 0.45
                    RadialGradient(colors: [colour.opacity(weight), .clear],
                                   center: centre, startRadius: 0, endRadius: spread)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
