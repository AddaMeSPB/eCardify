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

    // MARK: - Login Flow Test

    /// Tests the full OTP login flow end-to-end.
    /// Requires a running NeuAuth server at the configured URL with
    /// dev@ecardify.app set up as a test account (OTP code: 000000).
    func testLoginFlowEndToEnd() async throws {
        // Don't use the standard setup — we need a fresh app without -UI_TESTING
        let loginApp = XCUIApplication()
        loginApp.launchArguments = ["-hasSeenOnboarding", "YES"]
        loginApp.launch()

        // 1. Main screen should show "Login or Register" button
        let loginButton = loginApp.staticTexts["Login or Register"]
            .exists ? loginApp.staticTexts["Login or Register"]
            : loginApp.buttons.matching(NSPredicate(format: "label CONTAINS 'Login or Register'")).firstMatch
        XCTAssertTrue(
            loginButton.waitForExistence(timeout: 5),
            "Login or Register button should appear on the main screen"
        )

        // Take screenshot of unauthenticated state
        let emptyStateAttachment = XCTAttachment(screenshot: loginApp.screenshot())
        emptyStateAttachment.name = "Login_01_EmptyState"
        emptyStateAttachment.lifetime = .keepAlways
        add(emptyStateAttachment)

        // 2. Tap "Login or Register" to open the auth sheet
        loginButton.tap()
        try await Task.sleep(nanoseconds: 1_500_000_000)

        // 3. Verify email input field appears
        let emailField = loginApp.textFields["emailTF"]
        XCTAssertTrue(
            emailField.waitForExistence(timeout: 5),
            "Email text field should be visible on the login sheet"
        )

        // Take screenshot of login sheet
        let loginSheetAttachment = XCTAttachment(screenshot: loginApp.screenshot())
        loginSheetAttachment.name = "Login_02_EmailInput"
        loginSheetAttachment.lifetime = .keepAlways
        add(loginSheetAttachment)

        // 4. Type email
        emailField.tap()
        try await Task.sleep(nanoseconds: 500_000_000)
        emailField.typeText("dev@ecardify.app")
        try await Task.sleep(nanoseconds: 500_000_000)

        // Take screenshot with email filled
        let emailFilledAttachment = XCTAttachment(screenshot: loginApp.screenshot())
        emailFilledAttachment.name = "Login_03_EmailFilled"
        emailFilledAttachment.lifetime = .keepAlways
        add(emailFilledAttachment)

        // 5. Tap Continue / Send
        let sendButton = loginApp.buttons["sendEmailButtonTapped"]
        XCTAssertTrue(
            sendButton.waitForExistence(timeout: 3),
            "Continue button should be visible"
        )
        XCTAssertTrue(sendButton.isEnabled, "Continue button should be enabled for valid email")
        sendButton.tap()

        // 6. Wait for OTP code input to appear
        let codeField = loginApp.textFields["codeChangedTF"]
        XCTAssertTrue(
            codeField.waitForExistence(timeout: 10),
            "OTP code field should appear after sending email"
        )

        // Take screenshot of code input
        let codeInputAttachment = XCTAttachment(screenshot: loginApp.screenshot())
        codeInputAttachment.name = "Login_04_CodeInput"
        codeInputAttachment.lifetime = .keepAlways
        add(codeInputAttachment)

        // 7. Type the test OTP code
        codeField.tap()
        try await Task.sleep(nanoseconds: 500_000_000)
        codeField.typeText("000000")

        // 8. Wait for verification to complete — the app auto-verifies at 6 digits
        // After success, the login sheet should dismiss and we should see the authenticated state
        let settingsButton = loginApp.buttons["settings_button"]
        XCTAssertTrue(
            settingsButton.waitForExistence(timeout: 15),
            "Settings button should appear after successful login (authenticated state)"
        )

        // Take screenshot of authenticated state
        try await Task.sleep(nanoseconds: 1_000_000_000)
        let authStateAttachment = XCTAttachment(screenshot: loginApp.screenshot())
        authStateAttachment.name = "Login_05_Success"
        authStateAttachment.lifetime = .keepAlways
        add(authStateAttachment)
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
