import SwiftUI

// The second way to draw a trip (decision 30): a lit sign rather than a playing card. Deep
// ground, two bright inks, and the trip's own letter punched out of a dot matrix. Ten
// colourways, one per palette, all built the same way. Same data, no new model fields.
struct NeonCard: View {
    let trip: Trip
    var tilt: CGSize = .zero
    var holographic = false

    private var ink: NeonInk { NeonInk(hue: trip.cardPalette.neonHue) }

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
        .background(ink.ground)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(ink.rim, lineWidth: 4))
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
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func stat(_ label: String, _ value: String, of total: Int? = nil) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 8, weight: .medium).width(.expanded))
                .foregroundStyle(ink.glow2)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value).font(.system(size: 26, weight: .bold)).monospacedDigit()
                if let total {
                    Text("/\(total)").font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }

    private var footer: some View {
        Text(dateLine)
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .tracking(2)
            .foregroundStyle(.white.opacity(0.85))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(ink.haze.opacity(0.45))
    }
}

// Ten colourways, one per palette, every one built from the same three parts.
struct NeonInk {
    let hue: Double

    private func shifted(_ amount: Double) -> Double { (hue + amount).truncatingRemainder(dividingBy: 1) }

    var ground: LinearGradient {
        LinearGradient(colors: [Color(hue: hue, saturation: 0.9, brightness: 0.44),
                                Color(hue: shifted(0.05), saturation: 1, brightness: 0.18)],
                       startPoint: .top, endPoint: .bottom)
    }
    var glow: Color { Color(hue: hue, saturation: 0.8, brightness: 1) }
    var glow2: Color { Color(hue: shifted(0.45), saturation: 0.75, brightness: 1) }
    var haze: Color { Color(hue: hue, saturation: 0.85, brightness: 0.5) }
    var rim: LinearGradient {
        LinearGradient(colors: [glow, glow2], startPoint: .topLeading, endPoint: .bottomTrailing)
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

// The trip's letter, or a map pin, punched out of a field of dots. Which one is settled by the
// trip's seed, so a card never changes.
private struct DotMatrixMark: View {
    let trip: Trip
    let ink: NeonInk

    private var showsPin: Bool { trip.textureSeed.isMultiple(of: 2) }

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

    @ViewBuilder
    private func shape(in size: CGSize) -> some View {
        if showsPin {
            Image(systemName: "mappin.and.ellipse")
                .resizable()
                .scaledToFit()
                .frame(width: size.width, height: size.height)
        } else {
            Text(trip.initial)
                .font(.system(size: size.height * 1.05, weight: .heavy).width(.expanded))
                .frame(width: size.width, height: size.height)
        }
    }
}
