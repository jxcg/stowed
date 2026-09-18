import SwiftData
import SwiftUI

struct TripListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]
    @State private var isAdding = false
    @State private var tripToDelete: Trip?

    var body: some View {
        NavigationStack {
            Group {
                if trips.isEmpty {
                    ContentUnavailableView(
                        "No trips yet",
                        systemImage: "suitcase",
                        description: Text("Tap + to plan your first one.")
                    )
                } else {
                    List {
                        ForEach(trips) { trip in
                            NavigationLink(value: trip) {
                                HStack {
                                    Text(trip.name)
                                    Spacer()
                                    if trip.checkpoints.contains(where: { $0.kind == .return && $0.isClosed }) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundStyle(Color.accentColor)
                                            .accessibilityLabel("Trip complete")
                                    }
                                }
                            }
                        }
                        .onDelete { offsets in
                            tripToDelete = offsets.first.map { trips[$0] }
                        }
                    }
                }
            }
            .navigationTitle("Trips")
            .navigationDestination(for: Trip.self) { TripDetailView(trip: $0) }
            .toolbar {
                Button("Add trip", systemImage: "plus") { isAdding = true }
            }
            .sheet(isPresented: $isAdding) { TripForm() }
            // Delete cascades to everything under the trip. Confirm first.
            .confirmationDialog(
                "Delete \(tripToDelete?.name ?? "trip")?",
                isPresented: Binding(get: { tripToDelete != nil }, set: { if !$0 { tripToDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let trip = tripToDelete { context.delete(trip) }
                }
            } message: {
                Text("Its bags, items and checks go with it.")
            }
        }
    }
}

// New trip. Name required. Dates behind a toggle so an undated trip is name + Save.
private struct TripForm: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var hasDates = false
    @State private var startDate = Date.now
    @State private var endDate = Date.now

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Trip name", text: $name)
                Toggle("Dates", isOn: $hasDates)
                if hasDates {
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)
                    DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
            }
            .navigationTitle("New trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trip = Trip(
                            name: trimmedName,
                            startDate: hasDates ? startDate : nil,
                            endDate: hasDates ? endDate : nil
                        )
                        context.insert(trip)
                        // Both checks exist from day one (decision 7). After insert on purpose:
                        // that is when SwiftData persists relationships reliably.
                        _ = trip.checkpoint(.outbound)
                        _ = trip.checkpoint(.return)
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
    }
}
