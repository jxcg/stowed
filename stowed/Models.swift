import Foundation
import SwiftData

enum CheckpointKind: String, Codable {
    case outbound
    case `return`
}

@Model
final class Trip {
    var name: String
    var startDate: Date?
    var endDate: Date?
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \Bag.trip) var bags: [Bag] = []
    @Relationship(deleteRule: .cascade, inverse: \Checkpoint.trip) var checkpoints: [Checkpoint] = []

    init(name: String, startDate: Date? = nil, endDate: Date? = nil, createdAt: Date = .now) {
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = createdAt
    }

    var items: [Item] { bags.flatMap(\.items) }

    /// Case- and diacritic-insensitive substring match, scoped to this trip (SPEC §3.4).
    func items(matching query: String) -> [Item] {
        items.filter { $0.name.localizedStandardContains(query) }
    }

    /// Both checkpoints conceptually exist from trip creation (SPEC decision 7). They are
    /// materialised on first access because SwiftData does not reliably persist relationships
    /// assigned inside an initialiser, before the object is in a context.
    func checkpoint(_ kind: CheckpointKind) -> Checkpoint {
        if let existing = checkpoints.first(where: { $0.kind == kind }) { return existing }
        let created = Checkpoint(kind: kind)
        checkpoints.append(created)
        return created
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
}

@Model
final class Item {
    var name: String
    var emoji: String
    var addedAt: Date
    var notReturningAt: Date?
    var bag: Bag?
    @Relationship(deleteRule: .cascade, inverse: \Confirmation.item) var confirmations: [Confirmation] = []

    init(name: String, emoji: String, addedAt: Date = .now) {
        self.name = name
        self.emoji = emoji
        self.addedAt = addedAt
    }
}

@Model
final class Checkpoint {
    var kind: CheckpointKind
    var closedAt: Date?
    var trip: Trip?
    @Relationship(deleteRule: .cascade, inverse: \Confirmation.checkpoint) var confirmations: [Confirmation] = []

    init(kind: CheckpointKind) {
        self.kind = kind
    }

    var isClosed: Bool { closedAt != nil }

    // MARK: Expected set (SPEC §3.3, decisions 2 and 5)

    /// Closed: history frozen at `closedAt`. Open: current reality.
    /// Only the return check honours "not returning"; outbound still has to be packed.
    func expects(_ item: Item) -> Bool {
        if let closedAt {
            guard item.addedAt <= closedAt else { return false }
            if kind == .return, let markedAt = item.notReturningAt, markedAt <= closedAt { return false }
            return true
        }
        if kind == .return, item.notReturningAt != nil { return false }
        return true
    }

    var expectedItems: [Item] { trip?.items.filter(expects) ?? [] }

    // MARK: Progress — computed live, never stored (SPEC §3.3)

    var expectedCount: Int { expectedItems.count }

    /// Confirmations whose item is still in the expected set. A confirmation for an item
    /// that later left the set (deleted, or marked not-returning) simply stops counting.
    var confirmedCount: Int {
        confirmations.filter { $0.item.map(expects) ?? false }.count
    }

    var isComplete: Bool { confirmedCount == expectedCount }

    // MARK: Ticking (decisions 6 and 8)

    func isConfirmed(_ item: Item) -> Bool {
        confirmations.contains { $0.item === item }
    }

    /// No-op once closed, and never creates a duplicate for the same item.
    func confirm(_ item: Item, at date: Date = .now) {
        guard !isClosed, !isConfirmed(item) else { return }
        let confirmation = Confirmation(confirmedAt: date)
        confirmation.item = item
        confirmations.append(confirmation)
    }

    /// No-op once closed: a finished check is read-only.
    func unconfirm(_ item: Item) {
        guard !isClosed, let existing = confirmations.first(where: { $0.item === item }) else { return }
        confirmations.removeAll { $0 === existing }
        existing.modelContext?.delete(existing)
    }

    /// Permanent. There is no reopen (decision 6).
    func close(at date: Date = .now) {
        guard !isClosed else { return }
        closedAt = date
    }
}

@Model
final class Confirmation {
    var confirmedAt: Date
    var item: Item?
    var checkpoint: Checkpoint?

    init(confirmedAt: Date) {
        self.confirmedAt = confirmedAt
    }
}
