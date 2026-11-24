import XCTest

final class WorkingOutSmokeTests: XCTestCase {
    @MainActor
    func testLanguageAppliesImmediatelyAndSurvivesRelaunch() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        defer { app.terminate() }

        let profile = app.tabBars.buttons.matching(
            NSPredicate(format: "label == %@ OR label == %@", "Profile", "Profil")
        ).firstMatch
        XCTAssertTrue(profile.waitForExistence(timeout: 10))
        profile.tap()

        let picker = app.buttons["workingout.language"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.tap()
        let danish = app.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "Danish", "Dansk")).firstMatch
        XCTAssertTrue(danish.waitForExistence(timeout: 5))
        danish.tap()
        XCTAssertTrue(app.tabBars.buttons["Oversigt"].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Oversigt"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Profil"].tap()
        picker.tap()
        let english = app.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "English", "Engelsk")).firstMatch
        XCTAssertTrue(english.waitForExistence(timeout: 5))
        english.tap()
        XCTAssertTrue(app.tabBars.buttons["Overview"].waitForExistence(timeout: 5))
    }
}
