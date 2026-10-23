import SwiftData
import SwiftUI

// Two ways to see your trips (decision 22): a scrolling stack, or a pile you swipe through.
enum TripsView: String, CaseIterable {
    // ponytail: wallet and fan are two takes on the same idea, up for comparison (#60).
    // One of them goes once the owner picks.
    case stack, deck, wallet, fan
    var title: String { rawValue.capitalized }
}

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]
    // Swiping through playing cards is the way in (decision 27). The other layouts stay for now.
    @AppStorage("tripsView") private var view = TripsView.deck
    // Off by default (decision 23). Nothing in the simulator; needs a real phone.
    @AppStorage("motionEffect") private var motionEffect = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var motion = MotionReader()
    @AppStorage("cardStyle") private var cardStyle = CardStyle.metal
    @AppStorage("dividerShape") private var dividerShape = DividerShape.crease
    @State private var isAdding = false
    @State private var tripToDelete: Trip?
    @State private var openTrip: Trip?

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
            // Fill the screen so the fade's reader below starts at the top safe-area edge. The
            // deck alone is shorter and sits centred, which would read an inset of zero.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Set once here, above the deck, so the deck can hand the live value to the top card
            // alone. Set inside each card, it overrode that and every card redrew per tick.
            .modifier(LiveTilt(motion: motion))
            // Its own reader, so a safe-area change redraws the fade, not the whole screen.
            .overlay(alignment: .top) {
                GeometryReader { NavigationBlurFade(topInset: $0.safeAreaInsets.top) }
                    .allowsHitTesting(false)
            }
            .navigationTitle("Trips")
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(item: $openTrip) { TripDetailView(trip: $0) }
            .toolbar {
                Menu("More", systemImage: "ellipsis") {
                    Picker("View", selection: $view) {
                        ForEach(TripsView.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    Picker("Divider", selection: $dividerShape) {
                        ForEach(DividerShape.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    Picker("Card", selection: $cardStyle) {
                        ForEach(CardStyle.allCases, id: \.self) { Text($0.title).tag($0) }
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
                titleVisibility: .visible,
                presenting: tripToDelete
            ) { trip in
                Button("Delete", role: .destructive) { context.delete(trip) }
            } message: { _ in
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
        // Inset a little so a card never fills the screen edge to edge, and the pile behind shows.
        TripCardFlip(trip: trip, onEdit: { openTrip = trip }) {
            Button { openTrip = trip } label: {
                TripCard(trip: trip, holographic: motion.isRunning, style: cardStyle)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .contextMenu {
            Button("Delete", systemImage: "trash", role: .destructive) { tripToDelete = trip }
        }
    }
}

// Passes the phone's tilt down to the cards.
// In: the motion reader. Out: the same content, with the live tilt available to every card.
// Reading the tilt here, not in ContentView, means a tilt change redraws the cards and not the
// whole screen.
private struct LiveTilt: ViewModifier {
    let motion: MotionReader

    func body(content: Content) -> some View {
        content.environment(\.cardTilt, motion.tilt)
    }
}

// A frosted strip behind the title that fades out over the top of the cards.
// In: the height of the title bar (the top safe-area inset).
// Out: solid frost behind the bar, then a 72pt fade below it. It never takes touches.
private struct NavigationBlurFade: View {
    let topInset: CGFloat

    var body: some View {
        let fade: CGFloat = 72
        let height = topInset + fade
        Rectangle()
            .fill(.regularMaterial)
            .frame(height: height)
            .mask {
                LinearGradient(stops: [
                    .init(color: .white, location: 0),
                    .init(color: .white, location: topInset / height),
                    .init(color: .white.opacity(0.75), location: (topInset + fade * 0.3) / height),
                    .init(color: .white.opacity(0.25), location: (topInset + fade * 0.7) / height),
                    .init(color: .clear, location: 1)
                ], startPoint: .top, endPoint: .bottom)
            }
            .offset(y: -topInset)
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
