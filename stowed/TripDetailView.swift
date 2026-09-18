import SwiftData
import SwiftUI

struct TripDetailView: View {
    @Environment(\.modelContext) private var context
    let trip: Trip
    @State private var bagToEdit: Bag?
    @State private var isAdding = false
    @State private var bagToDelete: Bag?
    @State private var query = ""
    @State private var isStartingReturn = false

    var body: some View {
        Group {
            if !query.isEmpty {
                searchResults
            } else if trip.bags.isEmpty {
                ContentUnavailableView(
                    "No bags yet",
                    systemImage: "bag",
                    description: Text("Tap + to add a suitcase, backpack, anything.")
                )
            } else {
                List {
                    Section("Return") {
                        if trip.hasStartedReturn {
                            NavigationLink {
                                ReturnView(trip: trip)
                            } label: {
                                HStack {
                                    Text("Return check")
                                    Spacer()
                                    Text("\(trip.returnConfirmedCount) / \(trip.returnExpected.count)")
                                        .foregroundStyle(.secondary).monospacedDigit()
                                    if trip.isReturnComplete {
                                        Image(systemName: "checkmark.seal.fill").foregroundStyle(Color.accentColor)
                                            .accessibilityLabel("Complete")
                                    }
                                }
                            }
                        } else {
                            Button("Start return check", systemImage: "airplane.arrival") { isStartingReturn = true }
                        }
                    }
                    Section("Bags") {
                        ForEach(trip.bags) { bag in
                            NavigationLink(value: bag) {
                                HStack {
                                    Text(bag.emoji)
                                    Text(bag.name)
                                    Spacer()
                                    Text("\(bag.items.count)").foregroundStyle(.secondary)
                                }
                            }
                            .swipeActions {
                                Button("Delete", systemImage: "trash", role: .destructive) { bagToDelete = bag }
                                Button("Rename", systemImage: "pencil") { bagToEdit = bag }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(trip.name)
        .searchable(text: $query, prompt: "Find an item")
        .navigationDestination(for: Bag.self) { BagDetailView(bag: $0) }
        .toolbar {
            Button("Add bag", systemImage: "plus") { isAdding = true }
        }
        .sheet(isPresented: $isAdding) { BagForm(trip: trip, bag: nil) }
        // Re-import keeps every item; fresh expects nothing until you add or un-grey (decision 15).
        .confirmationDialog("Start the return check", isPresented: $isStartingReturn, titleVisibility: .visible) {
            Button("Re-import everything I packed") { trip.startReturn(reimport: true) }
            Button("Start fresh") { trip.startReturn(reimport: false) }
        } message: {
            Text("Re-import expects everything you packed to come home. Start fresh if it was all lost or replaced.")
        }
        .sheet(item: $bagToEdit) { BagForm(trip: trip, bag: $0) }
        .confirmationDialog(
            "Delete \(bagToDelete?.name ?? "bag")?",
            isPresented: Binding(get: { bagToDelete != nil }, set: { if !$0 { bagToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let bag = bagToDelete { context.delete(bag) }
            }
        } message: {
            Text("Its \(bagToDelete?.items.count ?? 0) items go with it.")
        }
    }
}

private extension TripDetailView {
    // The bag IS the answer. Bold it. Tap opens that bag.
    @ViewBuilder var searchResults: some View {
        let matches = trip.items(matching: query)
            .sorted { ($0.bag?.name ?? "", $0.name) < ($1.bag?.name ?? "", $1.name) }
        if matches.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            List(matches) { item in
                if let bag = item.bag {
                    NavigationLink(value: bag) {
                        HStack {
                            Text("\(item.emoji) \(item.name)")
                            Spacer()
                            Text("\(bag.emoji) \(bag.name)").fontWeight(.semibold)
                        }
                    }
                }
            }
        }
    }
}

// Add or rename a bag. bag == nil means add.
private struct BagForm: View {
    @Environment(\.dismiss) private var dismiss
    let trip: Trip
    let bag: Bag?
    @State private var name: String
    @State private var emoji: String
    @State private var lastGuess = ""

    init(trip: Trip, bag: Bag?) {
        self.trip = trip
        self.bag = bag
        _name = State(initialValue: bag?.name ?? "")
        _emoji = State(initialValue: bag?.emoji ?? "")
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                HStack {
                    EmojiField(emoji: $emoji, placeholder: EmojiGuess.bagFallback)
                    TextField("Bag name", text: $name)
                        .onChange(of: name) { _, new in
                            // Only overwrite our own guess. Anything the user typed stays.
                            let guess = EmojiGuess.guess(for: new, fallback: "")
                            if emoji.isEmpty || emoji == lastGuess { emoji = guess }
                            lastGuess = guess
                        }
                }
            }
            .navigationTitle(bag == nil ? "New bag" : "Rename bag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(); dismiss() }.disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private func save() {
        let finalEmoji = emoji.isEmpty ? EmojiGuess.bagFallback : emoji
        if let bag {
            bag.name = trimmedName
            bag.emoji = finalEmoji
        } else {
            trip.bags.append(Bag(name: trimmedName, emoji: finalEmoji))
        }
    }
}
