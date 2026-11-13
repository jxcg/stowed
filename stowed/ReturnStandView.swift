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
            Group {
                if let item {
                    current(item)
                } else if progress.isComplete {
                    Label("Everything's accounted for. Safe travels home.", systemImage: "checkmark.seal.fill")
                        .font(.headline)
                        .foregroundStyle(Color.accentColor)
                } else {
                    ContentUnavailableView("Nothing expected home", systemImage: "checklist")
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            buttons(for: item, queue: queue)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("One at a time")
        .navigationBarTitleDisplayMode(.inline)
        .navigationSubtitle("\(progress.confirmed) / \(progress.expected)")
        .sensoryFeedback(.success, trigger: progress.confirmed)
    }

    private func current(_ item: Item) -> some View {
        VStack(spacing: 8) {
            Text(item.emoji).font(.system(size: 96))
            Text(item.name).font(.largeTitle.bold()).multilineTextAlignment(.center)
            if item.quantityComingHome > 1 {
                Text("× \(item.quantityComingHome)").font(.title2).monospacedDigit().foregroundStyle(.secondary)
            }
            if let bag = item.bag {
                Text("\(bag.emoji) \(bag.name)").font(.headline).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("currentItem")
    }

    private func buttons(for item: Item?, queue: [Item]) -> some View {
        VStack(spacing: 12) {
            Button {
                item?.toggleReturnConfirmed()
            } label: {
                Label("Got it", systemImage: "checkmark")
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.borderedProminent)

            HStack(spacing: 12) {
                Button {
                    guard let item else { return }
                    putOff.insert(item.persistentModelID)
                    // Everything left has been put off: go round again.
                    if queue.allSatisfy({ putOff.contains($0.persistentModelID) }) { putOff = [] }
                } label: {
                    Label("Later", systemImage: "arrow.uturn.down").frame(maxWidth: .infinity, minHeight: 56)
                }
                .disabled(queue.count < 2)

                Button {
                    item?.returning = false
                } label: {
                    Label("Not returning", systemImage: "arrow.uturn.left.circle").frame(maxWidth: .infinity, minHeight: 56)
                }
            }
            .buttonStyle(.bordered)
        }
        .disabled(item == nil)
    }
}
