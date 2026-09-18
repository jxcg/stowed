import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]
    @State private var isAdding = false
    @State private var tripToDelete: Trip?

    // Upcoming trips first, soonest at the front. Undated and past trips after, newest first.
    private var orderedTrips: [Trip] {
        let today = Calendar.current.startOfDay(for: .now)
        let upcoming = trips.filter { ($0.endDate ?? $0.startDate ?? .distantPast) >= today }
            .sorted { ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) }
        let rest = trips.filter { !upcoming.contains($0) }
        return upcoming + rest
    }

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
                    stack
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
                Text("Its bags and items go with it.")
            }
        }
    }

    // Every trip is a tall card in a vertical stack (decision 18).
    private var stack: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(orderedTrips) { card($0) }
            }
            .padding()
        }
    }

    private func card(_ trip: Trip) -> some View {
        NavigationLink(value: trip) { TripCard(trip: trip) }
            .buttonStyle(.plain)
            .contextMenu {
                Button("Delete", systemImage: "trash", role: .destructive) { tripToDelete = trip }
            }
    }
}

// One trip as a card: name, dates, a collage of what is packed, counts, return state.
private struct TripCard: View {
    let trip: Trip

    // First 12 distinct emoji, in packing order.
    private var collage: [String] {
        var seen = Set<String>()
        return Array(trip.items.sorted { $0.addedAt < $1.addedAt }.map(\.emoji).filter { seen.insert($0).inserted }.prefix(12))
    }

    private var dates: String? {
        guard let start = trip.startDate else { return nil }
        let range = trip.endDate.map { start..<$0 }
        return range.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? start.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(trip.name).font(.title2.bold())
                Spacer()
                if trip.isReturnComplete {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(Color.accentColor)
                        .accessibilityLabel("Trip complete")
                }
            }
            if let dates {
                Text(dates).font(.subheadline).foregroundStyle(.secondary)
            }
            if collage.isEmpty {
                Text("Nothing packed yet").font(.subheadline).foregroundStyle(.secondary)
            } else {
                Text(collage.joined(separator: " ")).font(.title)
            }
            HStack {
                Text("\(trip.bags.count) bags · \(trip.items.count) items")
                Spacer()
                if trip.hasStartedReturn {
                    Text("Home \(trip.returnConfirmedCount) / \(trip.returnExpected.count)").monospacedDigit()
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.quaternary))
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
                        context.insert(Trip(
                            name: trimmedName,
                            startDate: hasDates ? startDate : nil,
                            endDate: hasDates ? endDate : nil
                        ))
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
    }
}
