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

    // Same matching Finder uses: ignores case and accents, partial words hit.
    func items(matching query: String) -> [Item] {
        items.filter { $0.name.localizedStandardContains(query) }
    }

    // Find or create. Why not in init? SwiftData drops relationships set before insert.
    // Net effect is the same: both checks exist from trip creation (decision 7).
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

    // MARK: Expected set

    // THE rule. Everything else hangs off this. SPEC 3.3.
    // Closed = frozen at closedAt. Open = what you have right now.
    // Only the RETURN check cares about "not returning". Outbound still has to be packed.
    func expects(_ item: Item) -> Bool {
        if let closedAt {
            guard item.addedAt <= closedAt else { return false }
            if kind == .return, let markedAt = item.notReturningAt, markedAt <= closedAt { return false }
            return true
        }
        if kind == .return, item.notReturningAt != nil { return false }
        return true
    }

    // MARK: Progress. Computed every time, never stored, so it cannot go stale.

    var expectedCount: Int { trip?.items.count(where: expects) ?? 0 }

    // Only ticks for items still expected. Deleted or not-returning items just stop counting.
    var confirmedCount: Int { confirmations.count { $0.item.map(expects) ?? false } }

    var isComplete: Bool { confirmedCount == expectedCount }

    // MARK: Ticking. Closed check = read only. No reopen, ever (decision 6).

    func isConfirmed(_ item: Item) -> Bool {
        confirmations.contains { $0.item === item }
    }

    func confirm(_ item: Item, at date: Date = .now) {
        guard !isClosed, !isConfirmed(item) else { return }
        let confirmation = Confirmation(confirmedAt: date)
        confirmation.item = item
        confirmations.append(confirmation)
    }

    func unconfirm(_ item: Item) {
        guard !isClosed, let existing = confirmations.first(where: { $0.item === item }) else { return }
        confirmations.removeAll { $0 === existing }
        existing.modelContext?.delete(existing)
    }

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
