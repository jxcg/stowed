import SwiftUI

// The only verification pass (decision 15). Tiles, tap to tick (decision 17). No finish, no lock.
// Unticked is grey on purpose: "not looked at yet", never "missing".
struct ReturnView: View {
    let trip: Trip
    @State private var tickCount = 0   // bumps on every tick so the haptic fires

    private let columns = [GridItem(.adaptive(minimum: 88), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if trip.isReturnComplete {
                    Label("Everything's accounted for. Safe travels home.", systemImage: "checkmark.seal.fill")
                        .font(.headline)
                        .foregroundStyle(Color.accentColor)
                }
                if trip.returnExpected.isEmpty {
                    ContentUnavailableView(
                        "Nothing expected home",
                        systemImage: "checklist",
                        description: Text("Long press a greyed item to mark it returning, or add something new.")
                    )
                }
                ForEach(trip.bags) { bag in
                    if !bag.items.isEmpty {
                        Text("\(bag.emoji) \(bag.name)").font(.headline)
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(bag.items.sorted { $0.addedAt < $1.addedAt }) { item in
                                ItemTile(item: item) { tickCount += 1 }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Return check")
        .navigationSubtitle("\(trip.returnConfirmedCount) / \(trip.returnExpected.count)")
        .sensoryFeedback(.success, trigger: tickCount)
    }
}

// Big emoji, name, count badge. Tap ticks. Long press for not-returning and quantity.
private struct ItemTile: View {
    let item: Item
    let onTick: () -> Void

    private var badge: String? {
        if item.returnQuantity != nil { return "\(item.quantityComingHome)/\(item.quantity)" }
        return item.quantity > 1 ? "\(item.quantity)" : nil
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(item.emoji).font(.system(size: 40))
            Text(item.name).font(.caption).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(item.isReturnConfirmed ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .topTrailing) {
            if let badge {
                Text(badge).font(.caption2).monospacedDigit()
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.thinMaterial, in: Capsule())
                    .padding(6)
            }
        }
        .overlay(alignment: .topLeading) {
            if item.isReturnConfirmed {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor).padding(6)
            }
        }
        .saturation(item.returning ? 1 : 0)
        .opacity(item.returning ? 1 : 0.5)
        .scaleEffect(item.isReturnConfirmed ? 1 : 0.96)
        .animation(.bouncy, value: item.isReturnConfirmed)
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture {
            guard item.returning else { return }
            item.toggleReturnConfirmed()
            onTick()
        }
        .contextMenu {
            if item.returning {
                Button("Not returning", systemImage: "arrow.uturn.left.circle") {
                    item.returning = false
                    item.returnConfirmedAt = nil
                }
                if item.quantity > 1 {
                    Button("One fewer coming home", systemImage: "minus.circle") {
                        item.returnQuantity = max(1, item.quantityComingHome - 1)
                    }
                    .disabled(item.quantityComingHome <= 1)
                    if item.returnQuantity != nil {
                        Button("All \(item.quantity) coming home", systemImage: "arrow.counterclockwise") {
                            item.returnQuantity = nil
                        }
                    }
                }
            } else {
                Button("Returning", systemImage: "arrow.uturn.right.circle") { item.returning = true }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(item.returning ? (item.isReturnConfirmed ? "Confirmed" : "Not yet verified") : "Not returning")
        .accessibilityAddTraits(.isButton)
    }
}
