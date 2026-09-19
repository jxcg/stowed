import Foundation
import SwiftData
import Testing
@testable import stowed

// Fresh in-memory store per test. Never touches real data.
private func makeContext() throws -> ModelContext {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Trip.self, configurations: config)
    return ModelContext(container)
}

private let t0 = Date(timeIntervalSince1970: 1_000_000)
private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

// One trip, one bag, `count` items, all added at t0.
private func makeTrip(items count: Int, in context: ModelContext) -> (Trip, Bag) {
    let trip = Trip(name: "Lisbon", createdAt: t0)
    context.insert(trip)
    let bag = Bag(name: "Suitcase", emoji: "🧳")
    trip.bags.append(bag)
    for i in 0..<count {
        bag.items.append(Item(name: "Item \(i)", emoji: "📦", addedAt: t0))
    }
    return (trip, bag)
}

@Suite struct ReturnSemantics {

    @Test func tickSetsAndClearsWithNoLock() throws {
        let context = try makeContext()
        let (trip, bag) = makeTrip(items: 1, in: context)
        let item = bag.items[0]
        trip.startReturn(reimport: true, at: at(1))

        item.toggleReturnConfirmed(at: at(2))
        #expect(item.returnConfirmedAt == at(2))
        #expect(trip.isReturnComplete)

        item.toggleReturnConfirmed()
        #expect(!item.isReturnConfirmed)
        #expect(!trip.isReturnComplete)
    }

    @Test func startFreshExpectsNothing() throws {
        let context = try makeContext()
        let (trip, bag) = makeTrip(items: 3, in: context)
        trip.startReturn(reimport: false, at: at(1))

        #expect(trip.returnExpected.isEmpty)
        #expect(bag.items.allSatisfy { !$0.returning })
        #expect(!trip.isReturnComplete)
        #expect(trip.returnStartedAt == at(1))
    }

    @Test func reimportExpectsEverything() throws {
        let context = try makeContext()
        let (trip, _) = makeTrip(items: 3, in: context)
        trip.startReturn(reimport: true, at: at(1))
        trip.startReturn(reimport: false, at: at(5))   // second start is ignored

        #expect(trip.returnExpected.count == 3)
        #expect(trip.returnStartedAt == at(1))
    }

    @Test func souvenirAddedAfterStartIsExpected() throws {
        let context = try makeContext()
        let (trip, bag) = makeTrip(items: 2, in: context)
        trip.startReturn(reimport: false, at: at(1))

        bag.items.append(Item(name: "Souvenir", emoji: "🎁", addedAt: at(2)))

        #expect(trip.returnExpected.map(\.name) == ["Souvenir"])
    }

    @Test func notReturningExcludedButStillPacked() throws {
        let context = try makeContext()
        let (trip, bag) = makeTrip(items: 2, in: context)
        let sunscreen = bag.items[0]
        sunscreen.quantity = 2
        trip.startReturn(reimport: true, at: at(1))

        sunscreen.returning = false

        #expect(trip.returnExpected.count == 1)
        #expect(bag.items.count == 2)
        #expect(sunscreen.quantity == 2)
    }

    @Test func returnQuantityLeavesPackedQuantityAlone() throws {
        let context = try makeContext()
        let (_, bag) = makeTrip(items: 1, in: context)
        let shirts = bag.items[0]
        shirts.quantity = 3
        #expect(shirts.quantityComingHome == 3)

        shirts.returnQuantity = 2

        #expect(shirts.quantity == 3)
        #expect(shirts.quantityComingHome == 2)
    }

    @Test func removingTickedItemKeepsReturnComplete() throws {
        let context = try makeContext()
        let (trip, bag) = makeTrip(items: 3, in: context)
        trip.startReturn(reimport: true, at: at(1))
        for item in bag.items { item.toggleReturnConfirmed(at: at(2)) }
        #expect(trip.isReturnComplete)

        context.delete(bag.items[0])
        try context.save()

        #expect(trip.returnExpected.count == 2)
        #expect(trip.isReturnComplete)
    }

    @Test func searchReturnsContainingBag() throws {
        let context = try makeContext()
        let (trip, bag) = makeTrip(items: 0, in: context)
        bag.items.append(Item(name: "Phone Charger", emoji: "🔌", addedAt: t0))
        bag.items.append(Item(name: "Socks", emoji: "🧦", addedAt: t0))

        let found = trip.items(matching: "char")
        #expect(found.map(\.name) == ["Phone Charger"])
        #expect(found.first?.bag === bag)
        #expect(trip.items(matching: "ZZZ").isEmpty)
    }

    @Test func deletingBagAndTripCascades() throws {
        let context = try makeContext()
        let (trip, bag) = makeTrip(items: 3, in: context)
        let other = Bag(name: "Backpack", emoji: "🎒")
        trip.bags.append(other)
        other.items.append(Item(name: "Book", emoji: "📖", addedAt: t0))
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Item>()) == 4)

        context.delete(bag)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Item>()) == 1)

        context.delete(trip)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Bag>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Item>()) == 0)
    }
}

@Suite struct UnhappyPaths {

    @Test func emptyTripIsNeverComplete() throws {
        let context = try makeContext()
        let trip = Trip(name: "Nowhere", createdAt: t0)
        context.insert(trip)
        trip.startReturn(reimport: true, at: at(1))

        #expect(trip.returnExpected.isEmpty)
        #expect(trip.returnConfirmedCount == 0)
        #expect(!trip.isReturnComplete)
    }

    @Test func bagWithNoItems() throws {
        let context = try makeContext()
        let (trip, _) = makeTrip(items: 0, in: context)
        #expect(trip.returnExpected.isEmpty)
        #expect(trip.items(matching: "a").isEmpty)
    }

    @Test func itemDeletedMidCheck() throws {
        let context = try makeContext()
        let (trip, bag) = makeTrip(items: 2, in: context)
        trip.startReturn(reimport: true, at: at(1))
        bag.items[0].toggleReturnConfirmed(at: at(2))
        #expect(trip.returnConfirmedCount == 1 && trip.returnExpected.count == 2)

        context.delete(bag.items[0])
        try context.save()

        #expect(trip.returnConfirmedCount == 0)
        #expect(trip.returnExpected.count == 1)
    }

    @Test func quantityNeverBelowOne() {
        let item = Item(name: "Socks", emoji: "🧦", quantity: 0)
        #expect(item.quantity == 1)
        item.changeQuantity(by: -5)
        #expect(item.quantity == 1)
        item.changeQuantity(by: 2)
        #expect(item.quantity == 3)
    }
}

@Suite struct Bags {
    @Test func addingAnExistingNameBumpsQuantity() throws {
        let context = try makeContext()
        let (_, bag) = makeTrip(items: 0, in: context)
        bag.add("T-shirt", emoji: "👕")
        bag.add("t-shirt", emoji: "👕")
        bag.add("Socks", emoji: "🧦")

        #expect(bag.items.count == 2)
        #expect(bag.items.first { $0.name == "T-shirt" }?.quantity == 2)
    }
}

@Suite struct SchemaMigration {
    // Root cause of "adding a trip shows nothing": a mandatory attribute with no default makes
    // lightweight migration fail and the store never loads. Every non-optional attribute
    // added after v0.1.0 must carry a default.
    @Test func newMandatoryAttributesHaveDefaults() throws {
        let schema = Schema([Trip.self])
        let added = [("Item", "quantity"), ("Item", "note"), ("Item", "returning"), ("Trip", "palette"), ("Trip", "suit"), ("Trip", "texture")]
        for (entityName, name) in added {
            let entity = try #require(schema.entities.first { $0.name == entityName })
            let attribute = try #require(entity.attributesByName[name])
            #expect(attribute.defaultValue != nil, "\(entityName).\(name) has no default, old stores cannot migrate")
        }
    }
}

