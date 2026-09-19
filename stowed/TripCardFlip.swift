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
        .overlay(alignment: .topTrailing) { buttons }
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
