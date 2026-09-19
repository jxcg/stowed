import SwiftUI

// A card with a back (decision 32). Quick view turns it over to everything packed, scrollable;
// edit opens the trip. The two buttons sit above the turn, so they never flip with it.
struct TripCardFlip<Front: View>: View {
    let trip: Trip
    let onEdit: () -> Void
    @ViewBuilder let front: () -> Front
    @State private var turned = false

    var body: some View {
        ZStack {
            front()
                .opacity(turned ? 0 : 1)
                .accessibilityHidden(turned)
            PackedBack(trip: trip)
                .opacity(turned ? 1 : 0)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .accessibilityHidden(!turned)
        }
        .rotation3DEffect(.degrees(turned ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
        .animation(.snappy(duration: 0.45), value: turned)
        .overlay(alignment: .bottomTrailing) { buttons }
    }

    private var buttons: some View {
        HStack(spacing: 8) {
            control(turned ? "arrow.uturn.backward" : "list.bullet",
                    label: turned ? "Back to the card" : "Quick view") { turned.toggle() }
            control("pencil", label: "Edit trip", action: onEdit)
        }
        .padding(14)
    }

    private func control(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)
                .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// The back of the card: what is in each bag, scrollable, with the return state where there is one.
private struct PackedBack: View {
    let trip: Trip
    @Environment(\.colorScheme) private var scheme
    @State private var phase: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(trip.name.uppercased())
                    .font(.system(size: 15, weight: .semibold).width(.expanded))
                Text("\(trip.bags.count) bags · \(trip.items.count) items")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 12)

            if trip.items.isEmpty {
                Text("Nothing packed yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(trip.bags) { bag in
                            if !bag.items.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("\(bag.emoji) \(bag.name)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    ForEach(bag.items.sorted { $0.addedAt < $1.addedAt }) { item in
                                        row(item)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 56)
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            ZStack {
                Chrome(phase: phase, dark: scheme == .dark)
                PrismSeam(phase: phase)
                // Keeps the writing legible over the metal.
                Rectangle().fill(.regularMaterial).opacity(0.72)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.7), .white.opacity(0.1),
                                            .white.opacity(0.45), .black.opacity(0.25)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1.2
                )
        }
        .aspectRatio(0.72, contentMode: .fit)
        .onAppear {
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) { phase = 1 }
        }
    }

    private func row(_ item: Item) -> some View {
        HStack(spacing: 8) {
            Text(item.emoji).saturation(item.returning ? 1 : 0)
            Text(item.name).font(.subheadline).lineLimit(1)
            if item.quantity > 1 {
                Text("×\(item.quantity)").font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            Spacer(minLength: 0)
            if trip.hasStartedReturn, item.returning {
                Image(systemName: item.isReturnConfirmed ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                    .foregroundStyle(item.isReturnConfirmed ? Color.accentColor : Color.secondary)
            }
        }
        .opacity(item.returning ? 1 : 0.5)
    }
}

// Liquid chrome, after the Siri icon in iOS 27: white through silver into graphite and back,
// turned slightly as it breathes so the metal never looks painted on.
private struct Chrome: View {
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
private struct PrismSeam: View {
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
