import SwiftUI

// The only verification pass (decision 15). Tiles, tap to tick (decision 17). No finish, no lock.
// Unticked is grey on purpose: "not looked at yet", never "missing".
struct ReturnView: View {
    let trip: Trip

    private let columns = [GridItem(.adaptive(minimum: 88), spacing: 12)]

    var body: some View {
        let progress = trip.returnProgress
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if progress.isComplete {
                    Label("Everything's accounted for. Safe travels home.", systemImage: "checkmark.seal.fill")
                        .font(.headline)
                        .foregroundStyle(Color.accentColor)
                }
                if progress.expected == 0 {
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
                            ForEach(bag.itemsInPackingOrder) { item in
                                ItemTile(item: item)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Return check")
        .navigationSubtitle("\(progress.confirmed) / \(progress.expected)")
        .sensoryFeedback(.success, trigger: progress.confirmed)
    }
}

// Big emoji, name, count badge. Tap ticks. Long press for not-returning and quantity.
private struct ItemTile: View {
    let item: Item

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
        }
        .contextMenu {
            if item.returning {
                // Keeps the tick, like the bag list does: switch it back and it is still confirmed.
                Button("Not returning", systemImage: "arrow.uturn.left.circle") { item.returning = false }
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
