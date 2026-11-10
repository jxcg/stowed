import Foundation
import SwiftData
import os

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
    @Relationship(deleteRule: .cascade, inverse: \TripPlan.trip) var plans: [TripPlan] = []

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

    var cardPalette: CardPalette { CardPalette(rawValue: palette) ?? .oxblood }

    // The itinerary, ready to draw.
    // In: this trip's plans. Out: one section per day, earliest first, then Unscheduled if any
    // plan has no day. Within a section, plans stay in the order they were created.
    var planSections: [PlanSection] {
        let ordered = plans.sorted { ($0.createdAt, $0.title) < ($1.createdAt, $1.title) }
        let byDay = Dictionary(grouping: ordered, by: \.day)
        let days = byDay.keys.compactMap { $0 }.sorted()
        return (days + (byDay[nil] == nil ? [] : [nil])).map { PlanSection(day: $0, plans: byDay[$0] ?? []) }
    }

    // Stable across launches: String.hashValue is not, so sum the scalars instead.
    var textureSeed: UInt64 {
        name.unicodeScalars.reduce(UInt64(createdAt.timeIntervalSince1970)) { $0 &* 31 &+ UInt64($1.value) }
    }

    var items: [Item] { bags.flatMap(\.items) }
    var itemCount: Int { bags.reduce(0) { $0 + $1.items.count } }

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
    var returnProgress: ReturnProgress {
        let expected = returnExpected
        return ReturnProgress(expected: expected.count, confirmed: expected.count(where: \.isReturnConfirmed))
    }
}

struct ReturnProgress {
    let expected: Int
    let confirmed: Int

    // Nothing expected home is not a completed check.
    var isComplete: Bool { expected > 0 && confirmed == expected }
}

enum PlanCategory: String, CaseIterable {
    case transport, stay, activity, note

    var title: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .transport: "airplane"
        case .stay: "bed.double"
        case .activity: "figure.walk"
        case .note: "note.text"
        }
    }
}

// One heading in the itinerary. A nil day is the Unscheduled section.
nonisolated struct PlanSection: Identifiable {
    let day: String?
    let plans: [TripPlan]

    var id: String { day ?? "unscheduled" }
}

// Converts between a picked date and the day a plan is stored under, "2026-11-09".
// A plan's day is a place on the calendar, not a moment. Stored as a Date it would slip to the
// day before or after when the phone changes time zone. Stored as text it cannot.
// Always Gregorian, so the text means the same thing on a phone set to any other calendar.
struct PlanDay {
    var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }()

    // In: a date from a picker. Out: its day in this calendar's time zone.
    func key(for date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    // In: a stored day. Out: the start of that day in this calendar's time zone, for showing it.
    func date(for key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

@Model
final class TripPlan {
    var title: String
    var category: String = PlanCategory.note.rawValue
    var location: String = ""
    var notes: String = ""
    var createdAt: Date
    // "2026-11-09", see PlanDay. nil = not on a day yet, which is also what older plans get.
    // Separate from the trip's own dates, so changing those never moves a plan.
    var day: String?
    var trip: Trip?

    init(title: String, category: PlanCategory = .note, location: String = "",
         notes: String = "", day: String? = nil, createdAt: Date = .now) {
        self.title = title
        self.category = category.rawValue
        self.location = location
        self.notes = notes
        self.day = day
        self.createdAt = createdAt
    }

    var planCategory: PlanCategory { PlanCategory(rawValue: category) ?? .note }
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

extension ModelContext {
    // Autosave runs on a delay, so a change is lost if the app is killed straight after it.
    // Packing edits call this instead of waiting. If the save fails the change stays in memory
    // and autosave tries again, so we log rather than interrupt a one-tap edit with an alert.
    func saveNow() {
        do {
            try save()
        } catch {
            Logger(subsystem: "stowed", category: "persistence").error("Save failed: \(error)")
        }
    }
}
