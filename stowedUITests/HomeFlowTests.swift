import XCTest

// Three small flows. Each does one job, asserts only what it set up, and leaves
// no cleanup behind: names carry a unique suffix, so leftovers from earlier runs
// cannot break a later run. The logic under the screens is covered by the unit
// tests in stowedTests; these cover what only a running app can.
final class HomeFlowTests: XCTestCase {

    // Creating a trip, a bag, and an item, end to end.
    @MainActor
    func testCreateTripBagAndItem() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-tripsView", "stack", "-bagView", "NO"]
        app.launch()

        createTripWithBagAndItem(app)
        XCUIDevice.shared.press(.home)
    }

    // What no unit test can check: the data reached disk before the app died.
    @MainActor
    func testDataSurvivesImmediateTermination() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-tripsView", "stack", "-bagView", "NO"]
        app.launch()
        let names = createTripWithBagAndItem(app)

        // No pause on purpose: autosave must not be what gets this to disk.
        app.terminate()
        app.launch()
        app.tabBars.buttons["Trips"].tap()
        let card = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", names.trip)).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "trip lost after termination")
        card.tap()
        XCTAssertTrue(app.staticTexts[names.bag].waitForExistence(timeout: 10), "bag lost after termination")
        app.staticTexts[names.bag].tap()
        XCTAssertTrue(app.staticTexts[names.item].waitForExistence(timeout: 10), "item lost after termination")
        XCUIDevice.shared.press(.home)
    }

    // #110's one-at-a-time return check is covered by a UI test in its own PR;
    // main's ReturnView is still the tile view, so there is nothing to drive here yet.

    // Shared setup: a trip holding a bag holding one item.
    // Ends inside the bag, after the item's row has appeared.
    @MainActor
    @discardableResult
    private func createTripWithBagAndItem(_ app: XCUIApplication) -> (trip: String, bag: String, item: String) {
        let suffix = UUID().uuidString.prefix(8)
        let tripName = "Trip \(suffix)"
        let bagName = "Bag \(suffix)"
        let itemName = "Item \(suffix)"

        app.tabBars.buttons["Trips"].tap()
        app.buttons["Add trip"].tap()
        XCTAssertTrue(app.textFields["Trip name"].waitForExistence(timeout: 10))
        app.textFields["Trip name"].tap()
        app.textFields["Trip name"].typeText(tripName)
        app.buttons["Create trip"].tap()
        XCTAssertTrue(app.navigationBars[tripName].waitForExistence(timeout: 10))

        app.buttons["Add bag"].tap()
        XCTAssertTrue(app.textFields["Bag name"].waitForExistence(timeout: 10))
        app.textFields["Bag name"].tap()
        app.textFields["Bag name"].typeText(bagName)
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts[bagName].waitForExistence(timeout: 10))
        app.staticTexts[bagName].tap()

        let addField = app.textFields["Add item"]
        XCTAssertTrue(addField.waitForExistence(timeout: 10))
        addField.tap()
        addField.typeText(itemName)
        app.buttons["Add"].tap()
        XCTAssertTrue(app.staticTexts[itemName].waitForExistence(timeout: 10))
        return (tripName, bagName, itemName)
    }
}
