import Foundation
import SwiftData
import Testing
@testable import stowed

@Suite struct TripPlans {
    private let timestamp = Date(timeIntervalSince1970: 1_000_000)

    private func withStore(_ test: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try test(directory.appendingPathComponent("test.store"))
    }

    @Test func plansSurviveReopeningAndEditing() throws {
        try withStore { url in
            try autoreleasepool {
                let container = try ModelContainer(for: Trip.self, configurations: ModelConfiguration(url: url))
                let context = ModelContext(container)
                let trip = Trip(name: "First trip")
                context.insert(trip)
                for category in PlanCategory.allCases {
                    trip.plans.append(TripPlan(title: category.rawValue, category: category,
                                               location: "Meeting point", notes: "Bring a ticket",
                                               createdAt: timestamp))
                }
                let bag = Bag(name: "Bag", emoji: "🎒")
                trip.bags.append(bag)
                bag.items.append(Item(name: "Ticket", emoji: "🎟️", quantity: 2))
                trip.startReturn(reimport: true, at: timestamp)
                bag.items[0].returnQuantity = 1
                bag.items[0].toggleReturnConfirmed(at: timestamp)
                try context.save()
            }

            try autoreleasepool {
                let container = try ModelContainer(for: Trip.self, configurations: ModelConfiguration(url: url))
                let context = ModelContext(container)
                let trip = try #require(context.fetch(FetchDescriptor<Trip>()).first)
                #expect(trip.plans.count == 4)
                for category in PlanCategory.allCases {
                    let plan = try #require(trip.plans.first { $0.title == category.rawValue })
                    #expect(plan.planCategory == category)
                    #expect(plan.location == "Meeting point")
                    #expect(plan.notes == "Bring a ticket")
                    #expect(plan.createdAt == timestamp)
                    #expect(plan.trip === trip)
                }
                let activity = try #require(trip.plans.first { $0.planCategory == .activity })
                activity.title = "Changed plan"
                activity.category = PlanCategory.stay.rawValue
                activity.location = ""
                activity.notes = "New details"
                let note = try #require(trip.plans.first { $0.planCategory == .note })
                context.delete(note)
                // Changing the trip dates must not discard its plans.
                trip.startDate = timestamp.addingTimeInterval(86_400)
                trip.endDate = timestamp.addingTimeInterval(172_800)
                try context.save()
            }

            try autoreleasepool {
                let container = try ModelContainer(for: Trip.self, configurations: ModelConfiguration(url: url))
                let context = ModelContext(container)
                let trip = try #require(context.fetch(FetchDescriptor<Trip>()).first)
                #expect(trip.plans.count == 3)
                let edited = try #require(trip.plans.first { $0.title == "Changed plan" })
                #expect(edited.planCategory == .stay)
                #expect(edited.location.isEmpty)
                #expect(edited.notes == "New details")
                #expect(trip.plans.allSatisfy { $0.planCategory != .note })
                #expect(trip.startDate == timestamp.addingTimeInterval(86_400))
                #expect(trip.endDate == timestamp.addingTimeInterval(172_800))
                #expect(trip.returnStartedAt == timestamp)
                #expect(trip.itemCount == 1)
                let item = try #require(trip.items.first)
                #expect(item.name == "Ticket")
                #expect(item.quantity == 2)
                #expect(item.returnQuantity == 1)
                #expect(item.returnConfirmedAt == timestamp)
                #expect(trip.returnProgress.isComplete)
            }
        }
    }

    @Test func deletingTripDeletesOnlyItsPlans() throws {
        try withStore { url in
            try autoreleasepool {
                let container = try ModelContainer(for: Trip.self, configurations: ModelConfiguration(url: url))
                let context = ModelContext(container)
                let first = Trip(name: "First")
                let second = Trip(name: "Second")
                context.insert(first)
                context.insert(second)
                first.plans.append(TripPlan(title: "Remove me"))
                first.plans.append(TripPlan(title: "Remove me too"))
                second.plans.append(TripPlan(title: "Keep me"))
                try context.save()
            }
            try autoreleasepool {
                let container = try ModelContainer(for: Trip.self, configurations: ModelConfiguration(url: url))
                let context = ModelContext(container)
                let first = try #require(context.fetch(FetchDescriptor<Trip>(
                    predicate: #Predicate { $0.name == "First" }
                )).first)
                // Delete a loaded trip without first loading its plans.
                context.delete(first)
                try context.save()
            }
            try autoreleasepool {
                let container = try ModelContainer(for: Trip.self, configurations: ModelConfiguration(url: url))
                let context = ModelContext(container)
                let trips = try context.fetch(FetchDescriptor<Trip>())
                #expect(trips.map(\.name) == ["Second"])
                let plans = try context.fetch(FetchDescriptor<TripPlan>())
                #expect(plans.map(\.title) == ["Keep me"])
                #expect(plans.first?.trip === trips.first)
                #expect(trips.first?.plans.count == 1)
            }
        }
    }

    @Test func existingPackingStoreGainsEmptyPlansWithoutLosingData() throws {
        try withStore { url in
            try autoreleasepool {
                let container = try ModelContainer(for: PackingBeforePlans.Trip.self,
                                                   configurations: ModelConfiguration(url: url))
                let context = ModelContext(container)
                let trip = PackingBeforePlans.Trip(name: "Existing trip", createdAt: timestamp)
                trip.startDate = timestamp.addingTimeInterval(100)
                trip.endDate = timestamp.addingTimeInterval(200)
                trip.returnStartedAt = timestamp.addingTimeInterval(300)
                trip.palette = "navy"
                trip.suit = "heart"
                trip.texture = "lattice"
                context.insert(trip)
                let bag = PackingBeforePlans.Bag(name: "Existing bag", emoji: "🎒")
                trip.bags.append(bag)
                let item = PackingBeforePlans.Item(name: "Existing item", emoji: "📦", addedAt: timestamp)
                item.quantity = 3
                item.note = "Keep dry"
                item.returnQuantity = 2
                item.returnConfirmedAt = timestamp.addingTimeInterval(400)
                bag.items.append(item)
                let excluded = PackingBeforePlans.Item(name: "Used up", emoji: "🧴", addedAt: timestamp)
                excluded.returning = false
                bag.items.append(excluded)
                context.insert(PackingBeforePlans.Trip(name: "Empty trip", createdAt: timestamp))
                try context.save()
            }

            try autoreleasepool {
                let container = try ModelContainer(for: Trip.self, configurations: ModelConfiguration(url: url))
                let context = ModelContext(container)
                let trips = try context.fetch(FetchDescriptor<Trip>())
                #expect(trips.count == 2)
                #expect(trips.allSatisfy { $0.plans.isEmpty })
                let empty = try #require(trips.first { $0.name == "Empty trip" })
                #expect(empty.bags.isEmpty)
                #expect(empty.startDate == nil && empty.endDate == nil && empty.returnStartedAt == nil)
                let trip = try #require(trips.first { $0.name == "Existing trip" })
                #expect(trip.createdAt == timestamp)
                #expect(trip.startDate == timestamp.addingTimeInterval(100))
                #expect(trip.endDate == timestamp.addingTimeInterval(200))
                #expect(trip.returnStartedAt == timestamp.addingTimeInterval(300))
                #expect(trip.palette == "navy" && trip.suit == "heart" && trip.texture == "lattice")
                #expect(trip.bags.count == 1)
                let bag = try #require(trip.bags.first)
                #expect(bag.name == "Existing bag" && bag.emoji == "🎒")
                #expect(bag.trip === trip)
                #expect(bag.items.count == 2)
                let item = try #require(bag.items.first { $0.name == "Existing item" })
                #expect(item.emoji == "📦" && item.addedAt == timestamp)
                #expect(item.quantity == 3 && item.note == "Keep dry")
                #expect(item.returning && item.returnQuantity == 2)
                #expect(item.returnConfirmedAt == timestamp.addingTimeInterval(400))
                #expect(item.bag === bag)
                let excluded = try #require(bag.items.first { $0.name == "Used up" })
                #expect(!excluded.returning && excluded.returnConfirmedAt == nil)
                #expect(trip.returnProgress.expected == 1 && trip.returnProgress.confirmed == 1)
                trip.plans.append(TripPlan(title: "First plan"))
                try context.save()
            }

            try autoreleasepool {
                let container = try ModelContainer(for: Trip.self, configurations: ModelConfiguration(url: url))
                let context = ModelContext(container)
                let plans = try context.fetch(FetchDescriptor<TripPlan>())
                #expect(plans.map(\.title) == ["First plan"])
                #expect(plans.first?.trip?.name == "Existing trip")
                #expect(try context.fetchCount(FetchDescriptor<Item>()) == 2)
            }
        }
    }
}
