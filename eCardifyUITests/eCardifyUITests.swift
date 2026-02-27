import XCTest

@MainActor
final class eCardifySnapshotTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        self.continueAfterFailure = false
        self.app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += ["-UI_TESTING"]
    }

    // MARK: - Snapshot Tests for App Store Screenshots

    func testAppStoreScreenshots() async throws {
        app.launch()

        // Wait for the app to load
        try await Task.sleep(nanoseconds: 2_000_000_000)

        // 1. Card List (Main Screen)
        snapshot("01_CardList")

        // 2. Navigate to Create Card Form
        let addButton = app.buttons["add_card_button"]
        if addButton.waitForExistence(timeout: 5) {
            addButton.tap()
            try await Task.sleep(nanoseconds: 1_000_000_000)

            // 3. Card Creation Form (empty)
            snapshot("02_CreateCard")

            // Fill in some sample data for a populated form screenshot
            let collectionViews = app.collectionViews

            let orgTextField = collectionViews.textFields["orgText"]
            if orgTextField.waitForExistence(timeout: 3) {
                orgTextField.tap()
                orgTextField.typeText("TechVentures Inc.")
            }

            let jobTitleTextField = collectionViews.textFields["jobTitleText"]
            if jobTitleTextField.waitForExistence(timeout: 3) {
                jobTitleTextField.tap()
                jobTitleTextField.typeText("Product Manager")
                dismissKeyboardIfNeeded()
            }

            let firstNameTextField = collectionViews.textFields["firstNameTextFields"]
            if firstNameTextField.waitForExistence(timeout: 3) {
                firstNameTextField.tap()
                firstNameTextField.typeText("Sarah")
                dismissKeyboardIfNeeded()
            }

            let lastNameTextField = collectionViews.textFields["lastNameTextFields"]
            if lastNameTextField.waitForExistence(timeout: 3) {
                lastNameTextField.tap()
                lastNameTextField.typeText("Johnson")
                dismissKeyboardIfNeeded()
            }

            let emailTextField = collectionViews.textFields["emailTextFields"]
            if emailTextField.waitForExistence(timeout: 3) {
                emailTextField.tap()
                emailTextField.typeText("sarah@techventures.com")
                dismissKeyboardIfNeeded()
            }

            try await Task.sleep(nanoseconds: 500_000_000)

            // 4. Card Form with data filled
            snapshot("03_CardFormFilled")

            // Scroll down to show more sections
            app.swipeUp()
            try await Task.sleep(nanoseconds: 500_000_000)
            snapshot("04_CardFormAddress")

            // Go back to the list
            app.navigationBars.buttons.element(boundBy: 0).tap()
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }

        // 5. Navigate to Settings
        let settingsButton = app.buttons["settings_button"]
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()
            try await Task.sleep(nanoseconds: 1_000_000_000)
            snapshot("05_Settings")

            // Go back from settings
            app.navigationBars.buttons.element(boundBy: 0).tap()
            try await Task.sleep(nanoseconds: 500_000_000)
        }
    }

    // MARK: - Helpers

    private func dismissKeyboardIfNeeded() {
        let returnKey = app.keyboards.buttons["Return"]
        if returnKey.exists && returnKey.isHittable {
            returnKey.tap()
            return
        }

        let dismissKey = app.keyboards.buttons["Dismiss"]
        if dismissKey.exists && dismissKey.isHittable {
            dismissKey.tap()
            return
        }

        // Tap center of screen to dismiss
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap()
    }
}
