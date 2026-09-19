import SwiftUI

// The same items the list shows, drawn as a packed bag (SPEC §2, decision 26). A view only:
// no new model fields, no new state. Confirmation is told apart four ways at once, not by
// colour alone: opacity, a tick glyph, upright versus tilted, and a ring.
struct BagVisualView: View {
    let bag: Bag
    let onTap: (Item) -> Void

    @Environment(\.colorScheme) private var scheme
    // The bag wears the same metal and ink as the trip's card.
    private var ink: NeonInk { NeonInk(accent: bag.trip?.cardPalette.neonAccent ?? 0.76, dark: scheme == .dark) }
    private var checking: Bool { bag.trip?.hasStartedReturn ?? false }
    private var items: [Item] { bag.items.sorted { $0.addedAt < $1.addedAt } }

    private let columns = [GridItem(.adaptive(minimum: 76), spacing: 14)]

    var body: some View {
        VStack(spacing: 0) {
            handle
            ZStack {
                RoundedRectangle(cornerRadius: 26).fill(ink.rim)
                shell.clipShape(RoundedRectangle(cornerRadius: 18)).padding(8)
                RoundedRectangle(cornerRadius: 15).strokeBorder(.white.opacity(0.3), lineWidth: 1).padding(13)

                if items.isEmpty {
                    Text("Empty").font(.system(.headline, design: .serif)).foregroundStyle(.white.opacity(0.7))
                        .padding(50)
                } else {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(items) { PackedItem(item: $0, checking: checking, onTap: onTap) }
                    }
                    .padding(28)
                }
            }
            latches
        }
    }

    // A capsule above the bag and two studs below read as luggage, not another card.
    private var handle: some View {
        Capsule()
            .strokeBorder(ink.rim, lineWidth: 7)
            .frame(width: 96, height: 30)
            .padding(.bottom, -14)
            .accessibilityHidden(true)
    }

    private var latches: some View {
        HStack(spacing: 120) {
            ForEach(0..<2, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 3).fill(ink.rim).frame(width: 34, height: 9)
            }
        }
        .padding(.top, -5)
        .accessibilityHidden(true)
    }

    private var shell: some View {
        ZStack {
            ink.ground
            if let trip = bag.trip {
                Chrome(phase: Double(trip.textureSeed % 100) / 100, dark: scheme == .dark)
                    .opacity(scheme == .dark ? 0.2 : 0.14)
                    .blendMode(.overlay)
            }
            // Items are the subject here; the texture stays behind them.
            Color.black.opacity(0.18)
        }
    }
}

// One item sitting in the bag.
private struct PackedItem: View {
    let item: Item
    let checking: Bool
    let onTap: (Item) -> Void

    private var confirmed: Bool { item.isReturnConfirmed }
    // Loose items lie at an angle; settled ones sit straight. Fixed per item so it never jitters.
    private var tilt: Double {
        guard checking, !confirmed else { return 0 }
        return Double(item.name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) } % 19) - 9
    }

    var body: some View {
        Button { onTap(item) } label: {
            VStack(spacing: 3) {
                Text(item.emoji)
                    .font(.system(size: 38))
                    .saturation(item.returning ? 1 : 0)
                    .overlay(alignment: .bottomTrailing) {
                        if checking, confirmed {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .background(Circle().fill(.black.opacity(0.35)))
                                .offset(x: 4, y: 2)
                        }
                    }
                Text(item.quantity > 1 ? "\(item.name) ×\(item.quantity)" : item.name)
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .padding(6)
            .background {
                if checking, confirmed {
                    Circle().stroke(.white.opacity(0.5), lineWidth: 1).scaleEffect(1.15)
                }
            }
            .rotationEffect(.degrees(tilt))
            .opacity(opacity)
        }
        .buttonStyle(.plain)
        .animation(.bouncy, value: confirmed)
        .accessibilityLabel(item.name)
        .accessibilityValue(accessibilityValue)
    }

    private var opacity: Double {
        if !item.returning { return 0.45 }
        if checking, !confirmed { return 0.6 }
        return 1
    }

    private var accessibilityValue: String {
        if !item.returning { return "Not returning" }
        guard checking else { return "Packed" }
        return confirmed ? "Confirmed" : "Not yet verified"
    }
}
