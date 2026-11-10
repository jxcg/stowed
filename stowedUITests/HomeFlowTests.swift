import XCTest

final class HomeFlowTests: XCTestCase {
    @MainActor
    func testCreateDatedTripFromTrips() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-tripsView", "stack"]
        app.launch()
        app.tabBars.buttons["Trips"].tap()
        app.buttons["Add trip"].tap()
        XCTAssertTrue(app.switches["Dates"].waitForExistence(timeout: 5))
        app.switches["Dates"].coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(app.switches["Dates"].value as? String, "1")
        let tripName = "Dated journey \(UUID().uuidString.prefix(8))"
        app.textFields["Trip name"].tap()
        app.textFields["Trip name"].typeText(tripName)
        app.buttons["Create trip"].tap()
        XCTAssertTrue(app.navigationBars[tripName].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        app.tabBars.buttons["Trips"].tap()
        let card = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", tripName)).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertFalse(card.label.contains("NO DATES"))
        card.press(forDuration: 2)
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 5))
        app.buttons["Delete"].tap()
        app.buttons["Delete"].tap()
        XCTAssertTrue(card.waitForNonExistence(timeout: 5))
        XCUIDevice.shared.press(.home)
    }

    // #103: tapping a bag row must open the bag, and so must a search result.
    @MainActor
    func testBagOpensFromRowAndFromSearch() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-tripsView", "stack"]
        app.launch()

        let tripName = "Bagged \(UUID().uuidString.prefix(8))"
        app.buttons["Add trip"].tap()
        app.textFields["Trip name"].tap()
        app.textFields["Trip name"].typeText(tripName)
        app.buttons["Create trip"].tap()
        XCTAssertTrue(app.navigationBars[tripName].waitForExistence(timeout: 5))

        app.buttons["Add bag"].tap()
        app.textFields["Bag name"].tap()
        app.textFields["Bag name"].typeText("Rucksack")
        app.buttons["Save"].tap()

        let bagRow = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Rucksack")).firstMatch
        XCTAssertTrue(bagRow.waitForExistence(timeout: 5))
        bagRow.tap()
        let addItem = app.textFields["Add item"]
        XCTAssertTrue(addItem.waitForExistence(timeout: 5), "Tapping the bag row did not open the bag")
        addItem.tap()
        addItem.typeText("Torch\n")
        XCTAssertTrue(app.staticTexts["Torch"].waitForExistence(timeout: 5))

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars[tripName].waitForExistence(timeout: 5))
        // With bags listed, the search field hides under the title until you pull down.
        let search = app.searchFields["Find an item"]
        if !search.waitForExistence(timeout: 2) { app.swipeDown() }
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Torch")
        let result = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Torch")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()
        XCTAssertTrue(addItem.waitForExistence(timeout: 5), "Tapping a search result did not open the bag")
        XCUIDevice.shared.press(.home)
    }

    @MainActor
    func testCreateTripFromMapAndReopenAfterRelaunch() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-tripsView", "stack"]
        app.launch()

        let mapTab = app.tabBars.buttons["Map"]
        XCTAssertTrue(mapTab.waitForExistence(timeout: 5))
        XCTAssertTrue(mapTab.isSelected)
        XCTAssertTrue(app.maps.firstMatch.exists)
        app.buttons["Add trip"].tap()

        let create = app.buttons["Create trip"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        XCTAssertFalse(create.isEnabled)
        let name = app.textFields["Trip name"]
        name.tap()
        name.typeText("   ")
        XCTAssertFalse(create.isEnabled)
        let cancelledName = "Cancelled \(UUID().uuidString.prefix(8))"
        name.typeText(cancelledName)
        XCTAssertTrue(create.isEnabled)
        app.buttons["Cancel"].tap()
        app.buttons["Add trip"].tap()
        XCTAssertEqual(app.textFields["Trip name"].value as? String, "Trip name")

        let tripName = "Journey \(UUID().uuidString.prefix(8))"
        app.textFields["Trip name"].tap()
        app.textFields["Trip name"].typeText("  \(tripName)  ")
        create.tap()
        XCTAssertTrue(app.navigationBars[tripName].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Add bag"].exists)
        XCTAssertTrue(app.tabBars.buttons["Trips"].isSelected)

        app.terminate()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Map"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Trips"].tap()
        XCTAssertFalse(app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", cancelledName)).firstMatch.exists)
        let card = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", tripName)).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(card.label.contains("NO DATES"))
        card.tap()
        XCTAssertTrue(app.navigationBars[tripName].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Add bag"].exists)

        app.navigationBars.buttons.firstMatch.tap()
        card.press(forDuration: 2)
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 5))
        app.buttons["Delete"].tap()
        app.buttons["Delete"].tap()
        XCTAssertTrue(card.waitForNonExistence(timeout: 5))
        XCUIDevice.shared.press(.home)
    }
}
