import SwiftUI

// A trip as a metal card (decisions 28, 30).
// In: the trip, and whether the motion effect is running.
// Out: a pale steel card with the trip's mark punched out of metal dots, the place in SF
// Extended and the dates along the bottom. Tilt the phone and the light moves across it.
struct TripCard: View {
    let trip: Trip
    var holographic = false
    @Environment(\.colorScheme) private var scheme
    // Raised while the card is being thrown, so the printing glimpses through.
    @Environment(\.cardReveal) private var reveal
    @Environment(\.cardTilt) private var tilt
    @Environment(\.cardLightOffset) private var lightOffset
    // ponytail: three shapes up for comparison. Two get deleted once one is chosen.
    @AppStorage("dividerShape") private var dividerShape = DividerShape.crease

    private var ink: NeonInk {
        NeonInk(accent: trip.cardPalette.neonAccent, dark: scheme == .dark,
                finish: trip.cardPalette.metalFinish, tilt: tilt)
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
                UltravioletLayer(trip: trip, ink: ink, strength: ultraviolet * 0.22)
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
                    .opacity(0.14)
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(ink.metalRim, lineWidth: 4))
        // A fine grain along the rim. Close enough to read as texture rather than a pattern.
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color.white.opacity(dark ? 0.1 : 0.2), style: StrokeStyle(lineWidth: 4, dash: [1.5, 2.5]))
        )
        .aspectRatio(0.72, contentMode: .fit)
        .shadow(color: .black.opacity(0.16), radius: 10, y: 6)
        .accessibilityElement(children: .combine)
    }

    private var backdrop: some View {
        BeadBlastSteel(tilt: tilt, lightOffset: lightOffset, warm: ink.glow, cool: ink.glow2)
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
                RadialGradient(colors: [ink.glow.opacity(0.16 + ultraviolet * 0.1),
                                        ink.glow.opacity(0.07 + ultraviolet * 0.08),
                                        .clear],
                               center: .center, startRadius: 0, endRadius: reach * (0.68 + ultraviolet * 0.18))
                DotMatrix(symbol: TripSymbol.forTrip(trip), metal: ink.metal)
                    // A specular sweep of its own, so the mark catches the light before the
                    // surface does and stands clear of the texture.
                    .overlay {
                        LinearGradient(stops: [.init(color: .clear, location: 0.3),
                                               .init(color: .white.opacity(0.3), location: 0.48),
                                               .init(color: .clear, location: 0.66)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                            .offset(x: -tilt.width * 7, y: -tilt.height * 7)
                            .blendMode(.plusLighter)
                            .mask(DotMatrix(symbol: TripSymbol.forTrip(trip), metal: ink.metal))
                    }
                    // Lifted off the sheet: its own contact shadow, thrown opposite the tilt.
                    .shadow(color: .black.opacity(0.3), radius: 3, x: -tilt.width * 0.5, y: 2 - tilt.height * 0.5)
                    .shadow(color: .white.opacity(0.12), radius: 7 + ultraviolet * 6)
                    .shadow(color: ink.glow.opacity(0.2), radius: 18 + ultraviolet * 10)
                    .brightness(ultraviolet * 0.04)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .animation(.easeOut(duration: 0.15), value: ultraviolet)
        .accessibilityHidden(true)
    }
}

// What the card hides until light of the right kind falls on it.
// In: the trip, its inks, and how strongly the light is hitting (0 to 1).
// Out: fine fibres scattered through the steel, placed the same way every time for this trip.
// Only drawn while the motion effect is on and the phone is actually tilted.
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
        }
        .blendMode(.plusLighter)
        .opacity(strength)
        .animation(.easeOut(duration: 0.15), value: strength)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
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
