import SwiftData
import SwiftUI

struct BagDetailView: View {
    @Environment(\.modelContext) private var context
    let bag: Bag
    @State private var newName = ""
    @State private var itemToEdit: Item?
    @FocusState private var addFieldFocused: Bool

    private var trimmedNewName: String { newName.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var sortedItems: [Item] { bag.items.sorted { $0.addedAt < $1.addedAt } }

    var body: some View {
        List {
            if bag.items.isEmpty {
                ContentUnavailableView(
                    "Nothing packed yet",
                    systemImage: "tshirt",
                    description: Text("Type below and hit return. Keep going.")
                )
                .listRowSeparator(.hidden)
            } else {
                ForEach(sortedItems) { item in
                    Button {
                        itemToEdit = item
                    } label: {
                        HStack {
                            Text(item.emoji).saturation(item.returning ? 1 : 0)
                            Text(item.name)
                            if !item.returning {
                                Spacer()
                                Text("Not returning").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .tint(item.returning ? .primary : .secondary)
                    .swipeActions {
                        Button("Delete", systemImage: "trash", role: .destructive) { context.delete(item) }
                        if item.returning {
                            Button("Not returning", systemImage: "arrow.uturn.left.circle") { item.returning = false }
                        } else {
                            Button("Returning", systemImage: "arrow.uturn.right.circle") { item.returning = true }
                        }
                    }
                }
            }

            // Add row never goes away. Twenty items = twenty returns. No sheet.
            Section {
                HStack {
                    Text(EmojiGuess.guess(for: newName, fallback: EmojiGuess.itemFallback))
                    TextField("Add item", text: $newName)
                        .focused($addFieldFocused)
                        .submitLabel(.done)
                        .onSubmit(addItem)
                    Button("Add", action: addItem).disabled(trimmedNewName.isEmpty)
                }
            }
        }
        .navigationTitle("\(bag.emoji) \(bag.name)")
        .sheet(item: $itemToEdit) { ItemForm(item: $0) }
    }

    private func addItem() {
        guard !trimmedNewName.isEmpty else { return }
        // addedAt is set to now in Item.init. Load-bearing: it decides which check an item joins.
        bag.items.append(Item(
            name: trimmedNewName,
            emoji: EmojiGuess.guess(for: trimmedNewName, fallback: EmojiGuess.itemFallback)
        ))
        newName = ""
        addFieldFocused = true
    }
}

// Rename, change emoji, or move to another bag in the same trip.
private struct ItemForm: View {
    @Environment(\.dismiss) private var dismiss
    let item: Item
    @State private var name: String
    @State private var emoji: String
    @State private var bag: Bag?

    init(item: Item) {
        self.item = item
        _name = State(initialValue: item.name)
        _emoji = State(initialValue: item.emoji)
        _bag = State(initialValue: item.bag)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var bagsInTrip: [Bag] { item.bag?.trip?.bags ?? [] }

    var body: some View {
        NavigationStack {
            Form {
                HStack {
                    EmojiField(emoji: $emoji, placeholder: EmojiGuess.itemFallback)
                    TextField("Item name", text: $name)
                }
                if bagsInTrip.count > 1 {
                    Picker("Bag", selection: $bag) {
                        ForEach(bagsInTrip) { candidate in
                            Text("\(candidate.emoji) \(candidate.name)").tag(Optional(candidate))
                        }
                    }
                }
            }
            .navigationTitle("Edit item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        item.name = trimmedName
                        item.emoji = emoji.isEmpty ? EmojiGuess.itemFallback : emoji
                        if let bag, bag !== item.bag { item.bag = bag }   // ticks move with it
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
    }
}
