import SwiftData
import SwiftUI

// The return check one item at a time (#110): the item on the top half, big buttons on the
// bottom half. Same ticks as the tile view, so the two can be mixed freely.
struct ReturnStandView: View {
    let trip: Trip
    // "Later" lasts for this visit only. Nothing about it is stored.
    @State private var putOff: Set<PersistentIdentifier> = []

    var body: some View {
        let queue = trip.returnQueue
        let progress = trip.returnProgress
        let item = Trip.nextToCheck(in: queue, putOff: putOff)
        VStack(spacing: 0) {
            ReturnStandItem(item: item, isComplete: progress.isComplete)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            ReturnStandButtons(item: item, queue: queue, putOff: $putOff)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("One at a time")
        .navigationBarTitleDisplayMode(.inline)
        .navigationSubtitle("\(progress.confirmed) / \(progress.expected)")
        .sensoryFeedback(.success, trigger: progress.confirmed)
    }
}

// What to look for next, or why there is nothing to look for.
private struct ReturnStandItem: View {
    let item: Item?
    let isComplete: Bool

    var body: some View {
        if let item {
            // A short window (large text, a small display) drops the big emoji before it clips.
            ViewThatFits(in: .vertical) {
                ReturnStandItemDetails(item: item, showsEmoji: true)
                ReturnStandItemDetails(item: item, showsEmoji: false)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("currentItem")
        } else if isComplete {
            Label("Everything's accounted for. Safe travels home.", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(.tint)
        } else {
            ContentUnavailableView("Nothing expected home", systemImage: "checklist")
        }
    }
}

private struct ReturnStandItemDetails: View {
    let item: Item
    let showsEmoji: Bool

    var body: some View {
        VStack {
            if showsEmoji {
                Text(item.emoji).font(.largeTitle.scaled(by: 2.8))
            }
            Text(item.name).font(.largeTitle).bold().multilineTextAlignment(.center)
            if item.quantityComingHome > 1 {
                Text("× \(item.quantityComingHome)").font(.title2).monospacedDigit().foregroundStyle(.secondary)
            }
            if let bag = item.bag {
                Text("\(bag.emoji) \(bag.name)").font(.headline).foregroundStyle(.secondary)
            }
        }
    }
}

private struct ReturnStandButtons: View {
    let item: Item?
    let queue: [Item]
    @Binding var putOff: Set<PersistentIdentifier>
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var context

    var body: some View {
        // Side by side until the text is too large to share a row.
        let row = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout()) : AnyLayout(HStackLayout())
        VStack {
            Button(action: confirm) {
                Label("Got it", systemImage: "checkmark")
                    .font(.largeTitle)
                    .bold()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.borderedProminent)

            row {
                Button(action: putOffCurrent) {
                    Label("Later", systemImage: "arrow.uturn.down").frame(maxWidth: .infinity)
                }
                .disabled(queue.count < 2)

                Button(action: markNotReturning) {
                    Label("Not returning", systemImage: "arrow.uturn.left.circle").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.extraLarge)
        }
        .disabled(item == nil)
    }

    private func confirm() {
        item?.toggleReturnConfirmed()
        context.saveNow()
    }

    private func putOffCurrent() {
        guard let item else { return }
        putOff.insert(item.persistentModelID)
        // Everything left has been put off: go round again.
        if queue.allSatisfy({ putOff.contains($0.persistentModelID) }) { putOff = [] }
    }

    private func markNotReturning() {
        item?.returning = false
        context.saveNow()
    }
}
