import Foundation
import SwiftData

// Frozen persisted shape before itinerary storage. Keep independent of the current models
// so the upgrade test creates an old store, rather than testing the new schema against itself.
enum PackingBeforePlans {
    @Model final class Trip {
        var name: String
        var startDate: Date?
        var endDate: Date?
        var createdAt: Date
        var returnStartedAt: Date?
        var palette: String = "oxblood"
        var suit: String = "spade"
        var texture: String = "scatter"
        @Relationship(deleteRule: .cascade, inverse: \Bag.trip) var bags: [Bag] = []

        init(name: String, createdAt: Date) {
            self.name = name
            self.createdAt = createdAt
        }
    }

    @Model final class Bag {
        var name: String
        var emoji: String
        var trip: Trip?
        @Relationship(deleteRule: .cascade, inverse: \Item.bag) var items: [Item] = []

        init(name: String, emoji: String) {
            self.name = name
            self.emoji = emoji
        }
    }

    @Model final class Item {
        var name: String
        var emoji: String
        var addedAt: Date
        var quantity: Int = 1
        var note: String = ""
        var returning: Bool = true
        var returnQuantity: Int?
        var returnConfirmedAt: Date?
        var bag: Bag?

        init(name: String, emoji: String, addedAt: Date) {
            self.name = name
            self.emoji = emoji
            self.addedAt = addedAt
        }
    }
}
