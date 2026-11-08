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
