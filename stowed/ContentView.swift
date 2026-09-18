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

// A playing card (decision 20). Gradient back from the trip's hue, paper face with a double
// rule, the initial in two corners like a real card, the packed emoji as the pips.
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

    private var light: Color { Color(hue: trip.hue, saturation: 0.6, brightness: 0.9) }
    private var dark: Color { Color(hue: (trip.hue + 0.1).truncatingRemainder(dividingBy: 1), saturation: 0.8, brightness: 0.55) }
    private var initial: String { String(trip.name.prefix(1)).uppercased() }
    private var pip: String { collage.first ?? "✈️" }

    var body: some View {
        ZStack {
            // Back: gradient plus a soft sheen, like light on a laminated card.
            RoundedRectangle(cornerRadius: 28)
                .fill(LinearGradient(colors: [light, dark], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(RadialGradient(colors: [.white.opacity(0.35), .clear], center: .topLeading, startRadius: 0, endRadius: 360))
                )
            // Face: paper panel with the classic double rule.
            RoundedRectangle(cornerRadius: 18)
                .fill(.background.opacity(0.94))
                .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(.secondary.opacity(0.35)).padding(6))
                .padding(16)

            VStack(spacing: 12) {
                Text(trip.name)
                    .font(.system(.title, design: .serif, weight: .bold))
                    .multilineTextAlignment(.center)
                if let dates {
                    Text(dates).font(.system(.subheadline, design: .serif)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if collage.isEmpty {
                    Text("Nothing packed yet").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text(collage.joined(separator: "  "))
                        .font(.system(size: 34))
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                }
                Spacer(minLength: 8)
                HStack {
                    Text("\(trip.bags.count) bags · \(trip.items.count) items")
                    Spacer()
                    if trip.isReturnComplete {
                        Label("Home", systemImage: "checkmark.seal.fill").foregroundStyle(Color.accentColor)
                            .accessibilityLabel("Trip complete")
                    } else if trip.hasStartedReturn {
                        Text("Home \(trip.returnConfirmedCount) / \(trip.returnExpected.count)").monospacedDigit()
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .padding(40)

            cornerMark
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            cornerMark
                .rotationEffect(.degrees(180))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .aspectRatio(0.72, contentMode: .fit)
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
    }

    private var cornerMark: some View {
        VStack(spacing: 0) {
            Text(initial).font(.system(.title2, design: .serif, weight: .bold))
            Text(pip).font(.caption)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 28)
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
