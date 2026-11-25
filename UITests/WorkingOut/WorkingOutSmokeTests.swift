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
    @MainActor
    func testBundledExerciseSearchAndInstructions() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        defer { app.terminate() }

        let start = app.buttons.matching(NSPredicate(
            format: "label == %@ OR label == %@", "Start strength training", "Start styrketræning"
        )).firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()
        let add = app.buttons["workingout.exercisePicker"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()

        let picker = app.navigationBars.matching(NSPredicate(
            format: "identifier == %@ OR identifier == %@", "Exercise library", "Øvelsesbibliotek"
        )).firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "An empty workout must still be able to present the exercise library.")
        let search = app.textFields["workingout.exerciseSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("Air Bike")
        let exercise = app.descendants(matching: .any).matching(identifier: "workingout.exercise.fedb:Air_Bike").firstMatch
        XCTAssertTrue(exercise.waitForExistence(timeout: 10))
        exercise.tap()
        XCTAssertTrue(app.navigationBars["Air Bike"].waitForExistence(timeout: 10))
    }

}
