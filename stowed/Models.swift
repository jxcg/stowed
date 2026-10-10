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
    // Card look, picked once at creation and kept (decisions 20, 21). Stored as raw strings so
    // adding a palette later is a new case, not a migration. Defaults are what old rows get.
    var palette: String = CardPalette.oxblood.rawValue
    var suit: String = CardSuit.spade.rawValue
    var texture: String = CardTexture.scatter.rawValue
    @Relationship(deleteRule: .cascade, inverse: \Bag.trip) var bags: [Bag] = []

    init(name: String, startDate: Date? = nil, endDate: Date? = nil, createdAt: Date = .now,
         palette: CardPalette = CardPalette.allCases.randomElement()!,
         suit: CardSuit = CardSuit.allCases.randomElement()!,
         texture: CardTexture = CardTexture.allCases.randomElement()!) {
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = createdAt
        self.palette = palette.rawValue
        self.suit = suit.rawValue
        self.texture = texture.rawValue
    }

    // The letter on the card, in the corners and as the watermark.
    var initial: String { String(name.prefix(1)).uppercased() }

    var cardPalette: CardPalette { CardPalette(rawValue: palette) ?? .oxblood }
    var cardSuit: CardSuit { CardSuit(rawValue: suit) ?? .spade }
    var cardTexture: CardTexture { CardTexture(rawValue: texture) ?? .scatter }

    // Stable across launches: String.hashValue is not, so sum the scalars instead.
    var textureSeed: UInt64 {
        name.unicodeScalars.reduce(UInt64(createdAt.timeIntervalSince1970)) { $0 &* 31 &+ UInt64($1.value) }
    }

    var items: [Item] { bags.flatMap(\.items) }
    var itemCount: Int { bags.reduce(0) { $0 + $1.items.count } }

    // Same matching Finder uses: ignores case and accents, partial words hit.
    func items(matching query: String) -> [Item] {
        bags.flatMap { bag in
            bag.items.filter { $0.name.localizedStandardContains(query) }
        }
    }

    // MARK: Return check (decision 15). No lock, no finish. Just a start.

    var hasStartedReturn: Bool { returnStartedAt != nil }

    // Re-import = keep every flag on (they already are). Fresh = everything off,
    // for "it all got lost or replaced". Items added later default to returning.
    func startReturn(reimport: Bool, at date: Date = .now) {
        guard returnStartedAt == nil else { return }
        returnStartedAt = date
        if !reimport {
            for bag in bags {
                for item in bag.items { item.returning = false }
            }
        }
    }

    // Live counts. Never stored, so never stale.
    var returnExpected: [Item] { items.filter(\.returning) }
    var returnProgress: ReturnProgress {
        var expected = 0
        var confirmed = 0
        for bag in bags {
            for item in bag.items where item.returning {
                expected += 1
                if item.isReturnConfirmed { confirmed += 1 }
            }
        }
        return ReturnProgress(expected: expected, confirmed: confirmed)
    }
}

struct ReturnProgress {
    let expected: Int
    let confirmed: Int

    // Nothing expected home is not a completed check.
    var isComplete: Bool { expected > 0 && confirmed == expected }
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

    var itemsInPackingOrder: [Item] { items.sorted { $0.addedAt < $1.addedAt } }

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
    }

    // Floor of 1. Item with count of zero means "delete it".
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
