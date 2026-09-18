import Foundation
import SwiftData

@Model
final class Trip {
    var name: String
    var startDate: Date?
    var endDate: Date?
    var createdAt: Date
    // nil = return check not started yet (decision 15).
    var returnStartedAt: Date?
    @Relationship(deleteRule: .cascade, inverse: \Bag.trip) var bags: [Bag] = []

    init(name: String, startDate: Date? = nil, endDate: Date? = nil, createdAt: Date = .now) {
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = createdAt
    }

    var items: [Item] { bags.flatMap(\.items) }

    // Same matching Finder uses: ignores case and accents, partial words hit.
    func items(matching query: String) -> [Item] {
        items.filter { $0.name.localizedStandardContains(query) }
    }

    // MARK: Return check (decision 15). No lock, no finish. Just a start.

    var hasStartedReturn: Bool { returnStartedAt != nil }

    // Re-import = keep every flag on (they already are). Fresh = everything off,
    // for "it all got lost or replaced". Items added later default to returning.
    func startReturn(reimport: Bool, at date: Date = .now) {
        guard returnStartedAt == nil else { return }
        returnStartedAt = date
        if !reimport {
            for item in items { item.returning = false }
        }
    }

    // Live counts. Never stored, so never stale.
    var returnExpected: [Item] { items.filter(\.returning) }
    var returnConfirmedCount: Int { returnExpected.count(where: \.isReturnConfirmed) }
    var isReturnComplete: Bool {
        !returnExpected.isEmpty && returnConfirmedCount == returnExpected.count
    }
}

@Model
final class Bag {
    var name: String
    var emoji: String
    var trip: Trip?
    @Relationship(deleteRule: .cascade, inverse: \Item.bag) var items: [Item] = []

    init(name: String, emoji: String) {
        self.name = name
        self.emoji = emoji
    }

    // Typing "T-shirt" again bumps the count instead of making a second row (decision 14).
    func add(_ name: String, emoji: String) {
        if let existing = items.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            existing.changeQuantity(by: 1)
        } else {
            items.append(Item(name: name, emoji: emoji))
        }
    }
}

@Model
final class Item {
    var name: String
    var emoji: String
    var addedAt: Date
    // Defaults here are load-bearing: they let old stores migrate. A mandatory attribute
    // with no default makes the store fail to load and the app runs with no store at all.
    var quantity: Int = 1
    var note: String = ""
    // Return side (decisions 15, 16). Absent returnConfirmedAt = not verified yet, never "missing".
    var returning: Bool = true
    var returnQuantity: Int?
    var returnConfirmedAt: Date?
    var bag: Bag?

    init(name: String, emoji: String, quantity: Int = 1, note: String = "", addedAt: Date = .now) {
        self.name = name
        self.emoji = emoji
        self.quantity = max(1, quantity)
        self.note = note
        self.addedAt = addedAt
        self.returning = true
    }

    // Floor of 1. Zero of something is "delete it".
    func changeQuantity(by delta: Int) {
        quantity = max(1, quantity + delta)
    }

    // What is coming home. nil returnQuantity = same as packed.
    var quantityComingHome: Int { returnQuantity ?? quantity }

    var isReturnConfirmed: Bool { returnConfirmedAt != nil }

    func toggleReturnConfirmed(at date: Date = .now) {
        returnConfirmedAt = isReturnConfirmed ? nil : date
    }
}
