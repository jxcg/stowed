import SwiftData
import SwiftUI

// Two ways to see your trips (decision 22): a scrolling stack, or a pile you swipe through.
enum TripsView: String, CaseIterable {
    // ponytail: wallet and fan are two takes on the same idea, up for comparison (#60).
    // One of them goes once the owner picks.
    case stack, deck, wallet, fan
    var title: String {
        switch self {
        case .stack: "Stack"
        case .deck: "Deck"
        case .wallet: "Wallet"
        case .fan: "Fan"
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]
    @AppStorage("tripsView") private var view = TripsView.stack
    // Off by default (decision 23). Nothing in the simulator; needs a real phone.
    @AppStorage("motionEffect") private var motionEffect = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var motion = MotionReader()
    @State private var isAdding = false
    @State private var tripToDelete: Trip?

    // Most recent first, oldest last, in both views (decision 27).
    private var orderedTrips: [Trip] {
        trips.sorted { ($0.startDate ?? $0.createdAt) > ($1.startDate ?? $1.createdAt) }
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
                    switch view {
                    case .deck: DeckView(trips: orderedTrips) { card($0) }
                    case .wallet: WalletView(trips: orderedTrips, layout: .cascade) { card($0) }
                    case .fan: WalletView(trips: orderedTrips, layout: .fan) { card($0) }
                    case .stack: stack
                    }
                }
            }
            .navigationTitle("Trips")
            .navigationDestination(for: Trip.self) { TripDetailView(trip: $0) }
            .toolbar {
                Menu("More", systemImage: "ellipsis") {
                    Picker("View", selection: $view) {
                        ForEach(TripsView.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    Toggle("Motion effect", isOn: $motionEffect)
                }
                Button("Add trip", systemImage: "plus") { isAdding = true }
            }
            .sheet(isPresented: $isAdding) { TripForm() }
            .onAppear(perform: syncMotion)
            .onDisappear(perform: motion.stop)
            .onChange(of: motionEffect) { syncMotion() }
            .onChange(of: reduceMotion) { syncMotion() }
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

    // Reads the phone's tilt only while this page is showing and the toggle is on.
    private func syncMotion() {
        if motionEffect, !reduceMotion { motion.start() } else { motion.stop() }
    }

    private func card(_ trip: Trip) -> some View {
        NavigationLink(value: trip) { TripCard(trip: trip, tilt: motion.tilt, holographic: motion.isRunning) }
            .buttonStyle(.plain)
            .contextMenu {
                Button("Delete", systemImage: "trash", role: .destructive) { tripToDelete = trip }
            }
    }
}

// New trip. Name required. Dates behind a toggle so an undated trip is name + Save.
private struct TripForm: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Trip.createdAt, order: .reverse) private var previous: [Trip]
    @State private var name = ""
    @State private var hasDates = false
    @State private var startDate = Date.now
    @State private var endDate = Date.now

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Trip name", text: $name)
                // One tap for the usual places; the field stays editable.
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(TripPresets.suggestions(previous: previous.map(\.name)), id: \.self) { preset in
                            Button(preset) { name = preset }.buttonStyle(.bordered)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 0))
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
