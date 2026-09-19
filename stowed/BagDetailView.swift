import SwiftData
import SwiftUI

// The bag list IS the packed list (decision 12). Rows with a stepper and a note (decision 17).
struct BagDetailView: View {
    @Environment(\.modelContext) private var context
    let bag: Bag
    // Same items, two presentations (decision 26). Remembered across bags and launches.
    @AppStorage("bagView") private var visual = false
    @State private var newName = ""
    @State private var itemToEdit: Item?
    @FocusState private var addFieldFocused: Bool

    private var trimmedNewName: String { newName.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var sortedItems: [Item] { bag.items.sorted { $0.addedAt < $1.addedAt } }

    var body: some View {
        Group {
            if visual { visualBag } else { list }
        }
        .navigationTitle("\(bag.emoji) \(bag.name)")
        .toolbar {
            Picker("View", selection: $visual) {
                Label("List", systemImage: "list.bullet").tag(false)
                Label("Bag", systemImage: "bag.fill").tag(true)
            }
            .pickerStyle(.segmented)
        }
        .sheet(item: $itemToEdit) { ItemForm(item: $0) }
    }

    // Tap an item to edit it, or to tick it off once the return check has started.
    private var visualBag: some View {
        ScrollView {
            BagVisualView(bag: bag) { item in
                if bag.trip?.hasStartedReturn == true, item.returning {
                    item.toggleReturnConfirmed()
                } else {
                    itemToEdit = item
                }
            }
            .padding()
        }
    }

    private var list: some View {
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
                    ItemRow(item: item) { itemToEdit = item }
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
    }

    private func addItem() {
        guard !trimmedNewName.isEmpty else { return }
        // Same name again = +1, not a duplicate row. addedAt is set in Item.init.
        bag.add(trimmedNewName, emoji: EmojiGuess.guess(for: trimmedNewName, fallback: EmojiGuess.itemFallback))
        newName = ""
        addFieldFocused = true
    }
}

// emoji | name + note | count | −/+. Tap the text to edit.
private struct ItemRow: View {
    @Bindable var item: Item
    let onTap: () -> Void
    // The bag view shows ticks during the return check, so the list shows them too.
    private var checking: Bool { item.bag?.trip?.hasStartedReturn ?? false }

    var body: some View {
        HStack {
            Button(action: onTap) {
                HStack {
                    if checking, item.returning {
                        Image(systemName: item.isReturnConfirmed ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(item.isReturnConfirmed ? Color.accentColor : Color.secondary)
                            .accessibilityLabel(item.isReturnConfirmed ? "Confirmed" : "Not yet verified")
                    }
                    Text(item.emoji).saturation(item.returning ? 1 : 0)
                    VStack(alignment: .leading) {
                        Text(item.name)
                        if !item.note.isEmpty {
                            Text(item.note).font(.caption).foregroundStyle(.secondary)
                        }
                        if !item.returning {
                            Text("Not returning").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .tint(item.returning ? .primary : .secondary)

            Stepper("\(item.quantity)", value: $item.quantity, in: 1...99)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .fixedSize()
        }
    }
}

// Rename, note, emoji, or move to another bag in the same trip.
private struct ItemForm: View {
    @Environment(\.dismiss) private var dismiss
    let item: Item
    @State private var name: String
    @State private var note: String
    @State private var emoji: String
    @State private var bag: Bag?

    init(item: Item) {
        self.item = item
        _name = State(initialValue: item.name)
        _note = State(initialValue: item.note)
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
                TextField("Note, e.g. 1x white, 3x black", text: $note)
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
                        item.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        item.emoji = emoji.isEmpty ? EmojiGuess.itemFallback : emoji
                        if let bag, bag !== item.bag { item.bag = bag }
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
    }
}
