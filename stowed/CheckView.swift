import SwiftData
import SwiftUI

extension CheckpointKind {
    var title: String { self == .outbound ? "Outbound" : "Return" }
}

/// One screen for both checks. Items are grouped by bag; a tap toggles the confirmation.
/// Unchecked is drawn neutrally on purpose: it means "not yet verified", never "missing".
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
                                confirmed ? checkpoint.unconfirm(item) : checkpoint.confirm(item)
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
        // Closing is permanent (SPEC decision 6), hence the confirm step.
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
