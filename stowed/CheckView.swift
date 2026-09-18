import SwiftUI

extension CheckpointKind {
    var title: String { self == .outbound ? "Outbound" : "Return" }
}

// One screen, both checks. Grouped by bag. Tap = toggle tick.
// Unchecked is grey on purpose. It means "not looked at yet", never "missing". No red.
struct CheckView: View {
    let trip: Trip
    let kind: CheckpointKind
    @State private var isConfirmingFinish = false

    private var checkpoint: Checkpoint { trip.checkpoint(kind) }

    var body: some View {
        List {
            if let closedAt = checkpoint.closedAt {
                Label("Finished \(closedAt.formatted(date: .abbreviated, time: .shortened))", systemImage: "lock")
                    .foregroundStyle(.secondary)
            }
            if checkpoint.expectedCount > 0, checkpoint.isComplete {
                Label(kind == .return ? "Everything's accounted for. Safe travels home." : "All packed.",
                      systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Color.accentColor)
                    .font(.headline)
            }
            if checkpoint.expectedCount == 0 {
                ContentUnavailableView("Nothing to check", systemImage: "checklist", description: Text("Add some items first."))
                    .listRowSeparator(.hidden)
            }
            ForEach(trip.bags) { bag in
                let expected = bag.items.filter(checkpoint.expects).sorted { $0.addedAt < $1.addedAt }
                if !expected.isEmpty {
                    Section("\(bag.emoji) \(bag.name)") {
                        ForEach(expected) { item in
                            let confirmed = checkpoint.isConfirmed(item)
                            Button {
                                if confirmed {
                                    checkpoint.unconfirm(item)
                                } else {
                                    checkpoint.confirm(item)
                                }
                            } label: {
                                Label {
                                    Text("\(item.emoji) \(item.name)")
                                } icon: {
                                    Image(systemName: confirmed ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(confirmed ? Color.accentColor : Color.secondary)
                                }
                            }
                            .tint(.primary)
                            .disabled(checkpoint.isClosed)
                            .accessibilityValue(confirmed ? "Confirmed" : "Not yet verified")
                            .swipeActions {
                                // A mark, not a delete. Outbound history stays (decision 4).
                                if kind == .return, !checkpoint.isClosed {
                                    Button("Not returning", systemImage: "arrow.uturn.left.circle") {
                                        item.notReturningAt = .now
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("\(kind.title) check")
        .navigationSubtitle("\(checkpoint.confirmedCount) / \(checkpoint.expectedCount)")
        .toolbar {
            if !checkpoint.isClosed {
                Button("Finish") { isConfirmingFinish = true }
            }
        }
        // Finish is forever (decision 6). Hence the confirm.
        .confirmationDialog(
            "Finish \(kind.title.lowercased()) check at \(checkpoint.confirmedCount) / \(checkpoint.expectedCount)?",
            isPresented: $isConfirmingFinish,
            titleVisibility: .visible
        ) {
            Button("Finish") { checkpoint.close() }
        } message: {
            Text("This can't be undone. Items added later go to the next check.")
        }
    }
}
