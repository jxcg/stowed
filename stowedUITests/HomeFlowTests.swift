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
        pressCardForDelete(card, app: app)
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
    func testPlanCanBeAddedScheduledAndDeleted() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-tripsView", "stack"]
        app.launch()

        let tripName = "Planned \(UUID().uuidString.prefix(8))"
        app.buttons["Add trip"].tap()
        app.textFields["Trip name"].tap()
        app.textFields["Trip name"].typeText(tripName)
        app.buttons["Create trip"].tap()
        XCTAssertTrue(app.navigationBars[tripName].waitForExistence(timeout: 5))

        app.buttons["Plans"].tap()
        XCTAssertTrue(app.staticTexts["No plans yet"].waitForExistence(timeout: 5))
        app.buttons["Add plan"].tap()
        XCTAssertFalse(app.buttons["Save"].isEnabled)
        app.textFields["Title"].tap()
        app.textFields["Title"].typeText("Museum")
        app.buttons["Save"].tap()

        // VoiceOver reads the kind of plan with its title, as one element.
        let row = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Museum")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Activity"))
        XCTAssertTrue(app.staticTexts["Unscheduled"].exists)

        row.tap()
        XCTAssertTrue(app.switches["On a day"].waitForExistence(timeout: 5))
        app.switches["On a day"].coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Unscheduled"].waitForNonExistence(timeout: 5))

        app.terminate()
        app.launch()
        app.tabBars.buttons["Trips"].tap()
        let card = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", tripName)).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        XCTAssertTrue(app.buttons["Plans"].waitForExistence(timeout: 5))
        app.buttons["Plans"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Unscheduled"].exists)

        // A long swipe deletes straight away; a short one shows the button.
        row.swipeLeft()
        if app.buttons["Delete"].waitForExistence(timeout: 2) { app.buttons["Delete"].tap() }
        XCTAssertTrue(app.staticTexts["No plans yet"].waitForExistence(timeout: 5))

        app.navigationBars.buttons.firstMatch.tap()
        app.navigationBars.buttons.firstMatch.tap()
        pressCardForDelete(card, app: app)
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
        pressCardForDelete(card, app: app)
        app.buttons["Delete"].tap()
        app.buttons["Delete"].tap()
        XCTAssertTrue(card.waitForNonExistence(timeout: 5))
        XCUIDevice.shared.press(.home)
    }

    // Regression for #107: packing changes must be on disk before the app can be killed.
    @MainActor
    func testBagAndItemSurviveImmediateTermination() {
        continueAfterFailure = false
        let app = XCUIApplication()
        // The add row only exists in the list presentation of a bag.
        app.launchArguments = ["-tripsView", "stack", "-bagView", "NO"]
        app.launch()
        app.tabBars.buttons["Trips"].tap()
        app.buttons["Add trip"].tap()
        let suffix = UUID().uuidString.prefix(8)
        let tripName = "Packing \(suffix)"
        let bagName = "Bag \(suffix)"
        let itemName = "Item \(suffix)"
        XCTAssertTrue(app.textFields["Trip name"].waitForExistence(timeout: 5))
        app.textFields["Trip name"].tap()
        app.textFields["Trip name"].typeText(tripName)
        app.buttons["Create trip"].tap()
        XCTAssertTrue(app.navigationBars[tripName].waitForExistence(timeout: 5))

        app.buttons["Add bag"].tap()
        XCTAssertTrue(app.textFields["Bag name"].waitForExistence(timeout: 5))
        app.textFields["Bag name"].tap()
        app.textFields["Bag name"].typeText(bagName)
        app.buttons["Save"].tap()
        let bagRow = app.staticTexts[bagName]
        XCTAssertTrue(bagRow.waitForExistence(timeout: 5))
        bagRow.tap()
        XCTAssertTrue(app.textFields["Add item"].waitForExistence(timeout: 5))
        app.textFields["Add item"].tap()
        app.textFields["Add item"].typeText(itemName)
        app.buttons["Add"].tap()
        let itemRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", itemName)).firstMatch
        XCTAssertTrue(itemRow.waitForExistence(timeout: 5))

        // No pause on purpose: autosave must not be what gets this to disk.
        app.terminate()
        app.launch()
        app.tabBars.buttons["Trips"].tap()
        let card = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", tripName)).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        XCTAssertTrue(bagRow.waitForExistence(timeout: 5), "bag lost after termination")
        bagRow.tap()
        XCTAssertTrue(itemRow.waitForExistence(timeout: 5), "item lost after termination")

        // Deletes save in the same tick the row goes away. Neither may crash the app.
        itemRow.swipeLeft()
        app.buttons["Delete"].firstMatch.tap()
        XCTAssertTrue(itemRow.waitForNonExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(bagRow.waitForExistence(timeout: 5))
        bagRow.swipeLeft()
        app.buttons["Delete"].firstMatch.tap()
        let confirmDelete = app.sheets.buttons["Delete"].firstMatch
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5))
        confirmDelete.tap()
        XCTAssertTrue(bagRow.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Add bag"].exists)
        app.navigationBars.buttons.firstMatch.tap()
        pressCardForDelete(card, app: app)
        app.buttons["Delete"].tap()
        app.buttons["Delete"].tap()
        XCTAssertTrue(card.waitForNonExistence(timeout: 5))
        XCUIDevice.shared.press(.home)
    }

    // #110: the return check one item at a time.
    @MainActor
    func testReturnCheckOneAtATime() {
        continueAfterFailure = false
        let app = XCUIApplication()
        // The add row only exists in the list presentation of a bag.
        app.launchArguments = ["-tripsView", "stack", "-bagView", "NO"]
        app.launch()
        app.tabBars.buttons["Trips"].tap()
        app.buttons["Add trip"].tap()
        let suffix = UUID().uuidString.prefix(8)
        let tripName = "Stand \(suffix)"
        let bagName = "Bag \(suffix)"
        let first = "Aaa \(suffix)"
        let second = "Bbb \(suffix)"
        XCTAssertTrue(app.textFields["Trip name"].waitForExistence(timeout: 5))
        app.textFields["Trip name"].tap()
        app.textFields["Trip name"].typeText(tripName)
        app.buttons["Create trip"].tap()
        XCTAssertTrue(app.navigationBars[tripName].waitForExistence(timeout: 5))

        app.buttons["Add bag"].tap()
        XCTAssertTrue(app.textFields["Bag name"].waitForExistence(timeout: 5))
        app.textFields["Bag name"].tap()
        app.textFields["Bag name"].typeText(bagName)
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts[bagName].waitForExistence(timeout: 5))
        app.staticTexts[bagName].tap()
        let addField = app.textFields["Add item"]
        XCTAssertTrue(addField.waitForExistence(timeout: 5))
        addField.tap()
        for name in [first, second] {
            addField.typeText(name)
            app.buttons["Add"].tap()
            let row = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", name)).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 5))
        }
        app.navigationBars.buttons.firstMatch.tap()

        app.buttons["Start return check"].tap()
        app.buttons["Re-import everything I packed"].tap()
        let returnLink = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "Return check")).firstMatch
        XCTAssertTrue(returnLink.waitForExistence(timeout: 5))
        returnLink.tap()
        app.buttons["One at a time"].tap()

        let current = app.descendants(matching: .any)["currentItem"]
        XCTAssertTrue(current.waitForExistence(timeout: 5))
        XCTAssertTrue(current.label.contains(first))
        app.buttons["Later"].tap()
        XCTAssertTrue(current.label.contains(second))
        app.buttons["Got it"].tap()
        XCTAssertTrue(current.label.contains(first))
        app.buttons["Got it"].tap()
        XCTAssertTrue(app.staticTexts["Everything's accounted for. Safe travels home."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Got it"].isEnabled)

        for _ in 0..<3 { app.navigationBars.buttons.firstMatch.tap() }
        let card = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", tripName)).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        pressCardForDelete(card, app: app)
        app.buttons["Delete"].tap()
        app.buttons["Delete"].tap()
        XCTAssertTrue(card.waitForNonExistence(timeout: 5))
        XCUIDevice.shared.press(.home)
    }

    // A long-press menu sometimes misses on a busy simulator, especially right after a pop.
    // Press again until Delete shows.
    @MainActor
    private func pressCardForDelete(_ card: XCUIElement, app: XCUIApplication) {
        for _ in 0..<3 {
            card.press(forDuration: 2)
            if app.buttons["Delete"].waitForExistence(timeout: 5) { return }
        }
        XCTFail("Delete never appeared from the card's context menu")
    }
}
