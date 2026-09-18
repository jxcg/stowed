import Foundation
import SwiftData
import Testing
@testable import stowed

// Swift Testing has its own `Confirmation`. Ours wins in this file.
private typealias Confirmation = stowed.Confirmation

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

@Suite struct CheckpointSemantics {

    @Test func confirmingOutboundLeavesReturnUnverified() throws {
        let context = try makeContext()
        let (trip, bag) = makeTrip(items: 1, in: context)
        let item = bag.items[0]
        trip.checkpoint(.outbound).confirm(item, at: at(1))

        #expect(trip.checkpoint(.outbound).isConfirmed(item))
        #expect(!trip.checkpoint(.return).isConfirmed(item))
        #expect(trip.checkpoint(.return).confirmedCount == 0)
    }

    @Test func souvenirAddedAfterCloseJoinsReturnOnly() throws {
        let context = try makeContext()
        let (trip, bag) = makeTrip(items: 10, in: context)
        let outbound = trip.checkpoint(.outbound)
        for item in bag.items { outbound.confirm(item, at: at(1)) }
        outbound.close(at: at(2))
        #expect(outbound.isComplete)

        bag.items.append(Item(name: "Souvenir", emoji: "🎁", addedAt: at(3)))

        #expect(outbound.confirmedCount == 10)
        #expect(outbound.expectedCount == 10)
        #expect(trip.checkpoint(.return).expectedCount == 11)
    }

    @Test func chargerAddedWhileOpenJoinsOutbound() throws {
        let context = try makeContext()
        let (trip, bag) = makeTrip(items: 10, in: context)
        let outbound = trip.checkpoint(.outbound)
        for item in bag.items.prefix(8) { outbound.confirm(item, at: at(1)) }

        bag.items.append(Item(name: "Charger", emoji: "🔌", addedAt: at(2)))

        #expect(outbound.confirmedCount == 8)
        #expect(outbound.expectedCount == 11)
    }

    @Test func notReturningOnlyAffectsReturn() throws {
        let context = try makeContext()
        let (trip, bag) = makeTrip(items: 2, in: context)
        let sunscreen = bag.items[0]
        let outbound = trip.checkpoint(.outbound)
        let ret = trip.checkpoint(.return)

        // Marked while outbound is still open: outbound still expects it (decision 5, case B).
        sunscreen.notReturningAt = at(1)
        #expect(outbound.expectedCount == 2)
        #expect(ret.expectedCount == 1)

        // Still present in the closed outbound check.
        outbound.close(at: at(2))
        #expect(outbound.expectedCount == 2)
    }

    @Test func notReturningFrozenAtReturnClose() throws {
        let context = try makeContext()
        let (trip, bag) = makeTrip(items: 2, in: context)
        let ret = trip.checkpoint(.return)

        // Marked before return closes: stays excluded after close (decision 5, case A).
        bag.items[0].notReturningAt = at(1)
        ret.confirm(bag.items[1], at: at(2))
        ret.close(at: at(3))
        #expect(ret.expectedCount == 1)
        #expect(ret.isComplete)

        // Marked after return closed: history is frozen, still included.
        bag.items[1].notReturningAt = at(4)
        #expect(ret.expectedCount == 1)
        #expect(ret.isComplete)
    }

    @Test func removingConfirmedItemFromClosedCheckKeepsItComplete() throws {
        let context = try makeContext()
        let (trip, bag) = makeTrip(items: 10, in: context)
        let outbound = trip.checkpoint(.outbound)
        for item in bag.items { outbound.confirm(item, at: at(1)) }
        outbound.close(at: at(2))

        context.delete(bag.items[0])
        try context.save()

        #expect(outbound.expectedCount == 9)
        #expect(outbound.confirmedCount == 9)
        #expect(outbound.isComplete)
    }

    @Test func removingUnconfirmedItemCompletesTheCheck() throws {
        let context = try makeContext()
        let (trip, bag) = makeTrip(items: 10, in: context)
        let outbound = trip.checkpoint(.outbound)
        for item in bag.items.dropFirst() { outbound.confirm(item, at: at(1)) }
        #expect(!outbound.isComplete)

        context.delete(bag.items[0])
        try context.save()

        #expect(outbound.isComplete)
        #expect(outbound.expectedCount == 9)
    }

    @Test func untickAllowedWhileOpenRefusedAfterClose() throws {
        let context = try makeContext()
        let (trip, bag) = makeTrip(items: 1, in: context)
        let item = bag.items[0]
        let outbound = trip.checkpoint(.outbound)

        outbound.confirm(item, at: at(1))
        outbound.confirm(item, at: at(1))          // duplicate is ignored
        #expect(outbound.confirmations.count == 1)
        outbound.unconfirm(item)
        #expect(!outbound.isConfirmed(item))

        outbound.confirm(item, at: at(2))
        outbound.close(at: at(3))
        outbound.unconfirm(item)
        #expect(outbound.isConfirmed(item))
        outbound.close(at: at(9))                  // second close does not move the date
        #expect(outbound.closedAt == at(3))
    }

    @Test func movingItemToAnotherBagKeepsConfirmations() throws {
        let context = try makeContext()
        let (trip, bag) = makeTrip(items: 1, in: context)
        let item = bag.items[0]
        let outbound = trip.checkpoint(.outbound)
        outbound.confirm(item, at: at(1))

        let other = Bag(name: "Backpack", emoji: "🎒")
        trip.bags.append(other)
        item.bag = other
        try context.save()

        #expect(bag.items.isEmpty)
        #expect(other.items.count == 1)
        #expect(outbound.isConfirmed(item))
        #expect(outbound.isComplete)
    }

    @Test func deletingBagCascadesToConfirmations() throws {
        let context = try makeContext()
        let (trip, bag) = makeTrip(items: 3, in: context)
        let outbound = trip.checkpoint(.outbound)
        for item in bag.items { outbound.confirm(item, at: at(1)) }
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Confirmation>()) == 3)

        context.delete(bag)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Item>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Confirmation>()) == 0)
        #expect(outbound.expectedCount == 0)
        #expect(outbound.confirmedCount == 0)
    }

    @Test func deletingTripCascadesEverything() throws {
        let context = try makeContext()
        let (trip, bag) = makeTrip(items: 2, in: context)
        trip.checkpoint(.outbound).confirm(bag.items[0], at: at(1))
        try context.save()

        context.delete(trip)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Bag>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Checkpoint>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Confirmation>()) == 0)
    }

    @Test func checkpointIsMaterialisedOnceAndPersisted() throws {
        let context = try makeContext()
        let (trip, _) = makeTrip(items: 0, in: context)
        let first = trip.checkpoint(.return)
        let second = trip.checkpoint(.return)
        try context.save()

        #expect(first === second)
        #expect(trip.checkpoints.count == 1)
        #expect(try context.fetchCount(FetchDescriptor<Checkpoint>()) == 1)
    }
}

@Suite struct UnhappyPaths {

    @Test func emptyTrip() throws {
        let context = try makeContext()
        let trip = Trip(name: "Nowhere", createdAt: t0)
        context.insert(trip)
        let outbound = trip.checkpoint(.outbound)

        #expect(outbound.expectedCount == 0)
        #expect(outbound.confirmedCount == 0)
        outbound.close(at: at(1))
        #expect(outbound.isClosed)
    }

    @Test func bagWithNoItems() throws {
        let context = try makeContext()
        let (trip, _) = makeTrip(items: 0, in: context)
        #expect(trip.checkpoint(.return).expectedCount == 0)
    }

    @Test func itemDeletedMidCheck() throws {
        let context = try makeContext()
        let (trip, bag) = makeTrip(items: 2, in: context)
        let outbound = trip.checkpoint(.outbound)
        outbound.confirm(bag.items[0], at: at(1))
        #expect(outbound.confirmedCount == 1 && outbound.expectedCount == 2)

        context.delete(bag.items[0])
        try context.save()

        #expect(outbound.confirmedCount == 0)
        #expect(outbound.expectedCount == 1)
        #expect(try context.fetchCount(FetchDescriptor<Confirmation>()) == 0)
    }
}

@Suite struct Search {
    @Test func partialCaseInsensitiveMatchReturnsContainingBag() throws {
        let context = try makeContext()
        let (trip, bag) = makeTrip(items: 0, in: context)
        bag.items.append(Item(name: "Phone Charger", emoji: "🔌", addedAt: t0))
        bag.items.append(Item(name: "Socks", emoji: "🧦", addedAt: t0))

        let found = trip.items(matching: "char")
        #expect(found.map(\.name) == ["Phone Charger"])
        #expect(found.first?.bag === bag)
        #expect(trip.items(matching: "ZZZ").isEmpty)
        #expect(Trip(name: "Empty").items(matching: "a").isEmpty)
    }
}
