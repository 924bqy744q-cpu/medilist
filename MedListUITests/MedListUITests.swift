import XCTest

/// End-to-end: onboarding → scan (sample label; the simulator has no camera) → confirm → save → flags → export.
final class MedListUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + extra
        app.launch()
        return app
    }

    private func snapshot(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testOnboardingScanConfirmSaveExport() throws {
        let app = launch()

        // Onboarding
        app.buttons["onboarding.continue"].tap()
        let name = app.textFields["onboarding.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Anna de Vries")
        app.buttons["onboarding.continue"].tap()
        let start = app.buttons["onboarding.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertFalse(start.isEnabled, "consent is required")
        // Tap the switch itself (right edge); long toggle labels do not toggle reliably when tapped in the middle.
        for id in ["onboarding.consent", "onboarding.disclaimer"] {
            let toggle = app.switches[id]
            // Form rows are lazy: scroll until the toggle exists and can be tapped.
            var tries = 0
            while !(toggle.exists && toggle.isHittable) && tries < 6 {
                app.swipeUp()
                tries += 1
            }
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        }
        XCTAssertTrue(start.isEnabled)
        start.tap()

        // Empty list → scan
        let scan = app.buttons["list.scan"]
        XCTAssertTrue(scan.waitForExistence(timeout: 5))
        scan.tap()
        let sample = app.buttons["scan.sample"]
        XCTAssertTrue(sample.waitForExistence(timeout: 5))
        sample.tap()

        // Confirm: extracted values are editable, nothing saved yet
        let drugName = app.textFields["field.drug_name"]
        XCTAssertTrue(drugName.waitForExistence(timeout: 10))
        XCTAssertEqual(drugName.value as? String, "Atorvastatin Calcium")
        XCTAssertEqual(app.textFields["field.strength"].value as? String, "20 mg")
        snapshot("confirm", app)
        app.buttons["confirm.save"].tap()

        // Saved to the list
        XCTAssertTrue(element(containing: "Atorvastatin Calcium", in: app).waitForExistence(timeout: 10))

        // Add the brand by hand → same active ingredient as the scanned generic
        app.buttons["list.add"].tap()
        let manualName = app.textFields["edit.drug_name"]
        XCTAssertTrue(manualName.waitForExistence(timeout: 5))
        manualName.tap()
        manualName.typeText("Lipitor")
        app.buttons["edit.save"].tap()
        XCTAssertTrue(element(containing: "Lipitor", in: app).waitForExistence(timeout: 10))

        let banner = app.buttons["list.flagBanner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 10), "brand + generic is flagged")
        snapshot("list-with-flag", app)
        banner.tap()
        let flag = app.descendants(matching: .any)["flag.duplicateIngredient"]
        XCTAssertTrue(flag.waitForExistence(timeout: 5))
        XCTAssertTrue(flag.label.contains("Verify with your pharmacist."), flag.label)
        snapshot("flags", app)
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // Export → share sheet
        app.buttons["list.export"].tap()
        let share = app.buttons["export.share"]
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        snapshot("export", app)
        share.tap()
        let shareSheet = app.otherElements["ActivityListView"]
        let copyAction = app.buttons["Copy"]
        XCTAssertTrue(shareSheet.waitForExistence(timeout: 10) || copyAction.exists, "system share sheet is shown")
        snapshot("share-sheet", app)
    }

    func testDiscardingAScanSavesNothing() {
        let app = launch(["-uitest-seed"])
        app.buttons["list.scan"].tap()
        app.buttons["scan.sample"].tap()
        XCTAssertTrue(app.textFields["field.drug_name"].waitForExistence(timeout: 10))
        app.buttons["confirm.discard"].tap()
        app.sheets.buttons["Discard"].firstMatch.tap()
        XCTAssertTrue(app.buttons["list.scan"].waitForExistence(timeout: 5))
        XCTAssertFalse(element(containing: "Atorvastatin Calcium", in: app).exists)
        XCTAssertTrue(element(containing: "Lipitor", in: app).exists, "seeded list is unchanged")
    }

    private func element(containing text: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }
}
