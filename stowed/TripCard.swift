import SwiftUI

// A trip, drawn once (decision 30): metal and light. A muted ground carrying splashes, a
// prismatic seam across it, the trip's mark punched out of metal dots, the place set in SF
// Extended, and the dates along the bottom. Same data, no new model fields.
struct TripCard: View {
    let trip: Trip
    var holographic = false
    // Passport is the plain printed card; metal adds chrome, seams and a specular band.
    var style: CardStyle = .metal
    @Environment(\.colorScheme) private var scheme
    // Raised while the card is being thrown, so the printing glimpses through.
    @Environment(\.cardReveal) private var reveal
    @Environment(\.cardTilt) private var tilt
    @Environment(\.cardLightOffset) private var lightOffset
    // ponytail: three shapes up for comparison. Two get deleted once one is chosen.
    @AppStorage("dividerShape") private var dividerShape = DividerShape.crease

    private var ink: NeonInk {
        NeonInk(accent: trip.cardPalette.neonAccent, dark: scheme == .dark,
                pearl: style == .metal, finish: trip.cardPalette.metalFinish, tilt: tilt)
    }

    private var dateLine: String {
        guard let start = trip.startDate else { return "NO DATES" }
        return start.formatted(.dateTime.day().month(.abbreviated).year()).uppercased()
    }

    private var dark: Bool { scheme == .dark }

    // How hard the light is hitting it. Nothing at rest, full at a good tilt.
    private var ultraviolet: Double {
        let fromTilt = holographic ? min(1, hypot(tilt.width, tilt.height) / 9) : 0
        return max(fromTilt, reveal)
    }

    var body: some View {
        VStack(spacing: 0) {
            TickStrip(ink: ink, ultraviolet: ultraviolet)
            DotMatrixMark(trip: trip, ink: ink, tilt: tilt, ultraviolet: ultraviolet)
                .frame(maxHeight: .infinity)
            TripCardChips(trip: trip, background: ink.haze, border: ink.glow)
            SectionDivider(ink: ink, shape: dividerShape)
            TripCardDetails(trip: trip, text: ink.text, shadow: dark ? .black : .white)
            footer
        }
        .background(backdrop)
        // Tilt it under the light and the security printing answers, the way a banknote does,
        // with a slick of spectrum across it like the holographic patch on the same note.
        .overlay {
            if ultraviolet > 0.01 {
                UltravioletLayer(trip: trip, ink: ink, strength: ultraviolet * (ink.pearl ? 0.22 : 1))
            }
        }
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
                    .opacity(ink.pearl ? 0.14 : 0.28)
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
        .shadow(color: .black.opacity(style == .metal ? 0.16 : 0.12), radius: 10, y: 6)
        .accessibilityElement(children: .combine)
    }

    // The ground is not just a gradient: colour thrown in from the other mode's base, the
    // place's own letter standing behind everything, and grain over the lot.
    private var backdrop: some View {
        ZStack {
            ink.ground
            if style == .passport { Splashes(trip: trip, ink: ink) }
            if style == .metal {
                BeadBlastSteel(tilt: tilt, lightOffset: lightOffset, warm: ink.glow, cool: ink.glow2)
            } else {
                MonogramField(initial: trip.initial, ink: ink)
            }
            if style == .passport {
                grain.resizable(resizingMode: .tile)
                    .opacity(dark ? 0.11 : 0.15)
                    .blendMode(dark ? .overlay : .multiply)
            }
        }
        .accessibilityHidden(true)
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
            .padding(.top, 26)
            .padding(.bottom, 16)
            // Fades up into the card rather than sitting on a hard band.
            .background(
                LinearGradient(stops: [.init(color: ink.separation.opacity(0), location: 0),
                                       .init(color: ink.separation.opacity(0.55), location: 0.45),
                                       .init(color: ink.separation.opacity(0.9), location: 1)],
                               startPoint: .top, endPoint: .bottom)
            )
    }
}

// A thin run of ticks along the top edge, alternating between the two inks.
private struct TickStrip: View {
    let ink: NeonInk
    var ultraviolet: Double = 0

    // Nothing to see in the hand. Turn the phone and the security printing answers, the way a
    // banknote's does under a lamp.
    private var lit: Color { Color(hue: 0.74, saturation: 0.55, brightness: 1) }

    var body: some View {
        HStack(spacing: 8) {
            Canvas { context, size in
                var x: CGFloat = 0
                var index = 0
                while x < size.width {
                    let tall = index.isMultiple(of: 4)
                    let height: CGFloat = tall ? 10 : 5
                    context.fill(Path(CGRect(x: x, y: (size.height - height) / 2, width: 2, height: height)),
                                 with: .color(tall ? lit : ink.glow2))
                    x += 7
                    index += 1
                }
            }
            // The marker that only the light brings up. The same one on every card.
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(lit)
                .shadow(color: lit.opacity(0.8), radius: 5)
        }
        // A trace of it at rest, so the strip is not a blank band, then it comes up with the tilt.
        .opacity(0.015 + ultraviolet * 0.985)
        .frame(height: 16)
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .animation(.easeOut(duration: 0.15), value: ultraviolet)
        .accessibilityHidden(true)
    }
}

// The trip's mark, lit from behind so it leads the card and burning harder under the blacklight.
private struct DotMatrixMark: View {
    let trip: Trip
    let ink: NeonInk
    var tilt: CGSize = .zero
    var ultraviolet: Double = 0

    var body: some View {
        GeometryReader { geometry in
            let reach = min(geometry.size.width, geometry.size.height)
            ZStack {
                RadialGradient(colors: [ink.glow.opacity((ink.pearl ? 0.16 : (ink.dark ? 0.34 : 0.25)) + ultraviolet * (ink.pearl ? 0.1 : 0.25)),
                                        ink.glow.opacity((ink.pearl ? 0.07 : (ink.dark ? 0.14 : 0.1)) + ultraviolet * 0.08),
                                        .clear],
                               center: .center, startRadius: 0, endRadius: reach * (0.68 + ultraviolet * 0.18))
                DotMatrix(symbol: TripSymbol.forTrip(trip), metal: ink.metal)
                    // A specular sweep of its own, so the mark catches the light before the
                    // surface does and stands clear of the texture.
                    .overlay {
                        LinearGradient(stops: [.init(color: .clear, location: 0.3),
                                               .init(color: .white.opacity(ink.pearl ? 0.3 : 0.85), location: 0.48),
                                               .init(color: .clear, location: 0.66)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                            .offset(x: -tilt.width * 7, y: -tilt.height * 7)
                            .blendMode(.plusLighter)
                            .mask(DotMatrix(symbol: TripSymbol.forTrip(trip), metal: ink.metal))
                    }
                    // Lifted off the sheet: its own contact shadow, thrown opposite the tilt.
                    .shadow(color: .black.opacity(0.3), radius: 3, x: -tilt.width * 0.5, y: 2 - tilt.height * 0.5)
                    .shadow(color: .white.opacity(ink.pearl ? 0.12 : (ink.dark ? 0.5 : 0.3)), radius: 7 + ultraviolet * 6)
                    .shadow(color: ink.glow.opacity(ink.pearl ? 0.2 : 0.35 + ultraviolet * 0.35), radius: 18 + ultraviolet * 10)
                    .brightness(ultraviolet * (ink.pearl ? 0.04 : 0.18))
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .animation(.easeOut(duration: 0.15), value: ultraviolet)
        .accessibilityHidden(true)
    }
}

// What the card hides until light of the right kind falls on it: fibres through the stock, a
// thread down one side, and the trip's own letter watermarked across the middle. Only drawn
// while the motion effect is on and the phone is actually tilted.
private struct UltravioletLayer: View {
    let trip: Trip
    let ink: NeonInk
    let strength: Double

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
                let tint = random.unit() > 0.5 ? ink.text : ink.glow2
                context.stroke(fibre, with: .color(tint.opacity(0.55 + random.unit() * 0.45)), lineWidth: 1.1)
            }

            // On a pale sheet the fibres are enough; a thread and a watermark just burn out.
            guard !ink.pearl else { return }

            // The thread, dashed, running the height of the card.
            let threadX = size.width * 0.82
            var thread = Path()
            thread.move(to: CGPoint(x: threadX, y: 0))
            thread.addLine(to: CGPoint(x: threadX, y: size.height))
            context.stroke(thread, with: .color(ink.glow2.opacity(0.7)),
                           style: StrokeStyle(lineWidth: 3, dash: [9, 5]))

            // The watermark, only readable under the light.
            let mark = context.resolve(
                Text(trip.initial)
                    .font(.system(size: size.height * 0.34, weight: .black).width(.expanded))
                    .foregroundStyle(ink.glow2.opacity(0.5))
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

    // Deterministic placement: a splash never moves when the card redraws.
    private struct Placement {
        let centre: UnitPoint
        let spread: CGFloat
        let weight: Double
    }

    private var placements: [Placement] {
        var random = SeededRandom(seed: trip.textureSeed)
        return (0..<2).map { _ in
            Placement(centre: UnitPoint(x: random.unit(), y: random.unit()),
                      spread: 0.35 + random.unit() * 0.55,
                      weight: 0.12 + random.unit() * 0.24)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let reach = max(geometry.size.width, geometry.size.height)
            ZStack {
                ForEach(Array(placements.enumerated()), id: \.offset) { index, spot in
                    let colour = index == 1 ? ink.glow : ink.splash
                    RadialGradient(colors: [colour.opacity(spot.weight), .clear],
                                   center: spot.centre, startRadius: 0, endRadius: reach * spot.spread)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// Two ways to print the same card (decision 28).
enum CardStyle: String, CaseIterable {
    case passport, metal
    var title: String { self == .passport ? "Passport" : "Metal" }
}

// Where the card stops being a picture and starts being a record. Three ways to draw that.
enum DividerShape: String, CaseIterable {
    case crease, ticket, sweep
    var title: String { rawValue.capitalized }
}

private struct SectionDivider: View {
    let ink: NeonInk
    let shape: DividerShape

    var body: some View {
        switch shape {
        case .crease:
            // A fold pressed into the sheet: shadow above the line, light below it.
            VStack(spacing: 0) {
                Rectangle().fill(.black.opacity(0.18)).frame(height: 1.5)
                Rectangle().fill(.white.opacity(0.6)).frame(height: 1.5)
            }
            .padding(.horizontal, 10)

        case .ticket:
            // Cut like a stub, with a perforation running between the notches.
            ZStack {
                Rectangle()
                    .fill(ink.text.opacity(0.35))
                    .frame(height: 1.5)
                    .mask(
                        HStack(spacing: 5) {
                            ForEach(0..<40, id: \.self) { _ in Rectangle().frame(width: 4) }
                        }
                    )
                HStack {
                    notch
                    Spacer()
                    notch
                }
            }
            .frame(height: 16)
            .padding(.horizontal, -2)

        case .sweep:
            // The two halves parted by a shallow curve rather than a straight cut.
            Arc()
                .stroke(LinearGradient(colors: [.white.opacity(0.5), ink.text.opacity(0.4), .white.opacity(0.5)],
                                       startPoint: .leading, endPoint: .trailing),
                        lineWidth: 2.5)
                .frame(height: 18)
                .padding(.horizontal, 6)
        }
    }

    private var notch: some View {
        Circle()
            .fill(.black.opacity(0.22))
            .frame(width: 14, height: 14)
            .blendMode(.multiply)
    }
}

nonisolated private struct Arc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY - 5))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY - 5),
                          control: CGPoint(x: rect.midX, y: rect.midY + 12))
        return path
    }
}
