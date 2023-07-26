import XCTest

@testable import GenericPassFeature
@testable import AuthenticationView

@MainActor
final class eCardifySPMTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
      self.continueAfterFailure = false
      self.app = XCUIApplication()
      setupSnapshot(app)
      app.launchEnvironment = [
        "UITesting": "true"
      ]

    }

    func testFillUpFormContact() async throws {
        app.launch()

        snapshot("List")

        app.buttons["add_card_button"].tap()

        let collectionViews = app.collectionViews
        snapshot("form")

        let organizationTextField = collectionViews.textFields[UITestGPFAccessibilityIdentifier.orgText.rawValue]
        organizationTextField.tap()
        organizationTextField.typeText("Addame It.")

        let jobTitleTextField = collectionViews.textFields[UITestGPFAccessibilityIdentifier.jobTitleText.rawValue]
        jobTitleTextField.tap()
        jobTitleTextField.typeText("CEO & Swift Developer")
        app.keyboards.buttons["Return"].tap()

        let firstNameTextField = collectionViews.textFields[UITestGPFAccessibilityIdentifier.firstNameTextFields.rawValue]
        firstNameTextField.tap()
        firstNameTextField.typeText("Jhon")
        app.keyboards.buttons["Return"].tap()

        let lastNameTextField = collectionViews.textFields[UITestGPFAccessibilityIdentifier.lastNameTextFields.rawValue]
        lastNameTextField.tap()
        lastNameTextField.typeText("Blob")
        app.keyboards.buttons["Return"].tap()

        let telephonTextField = collectionViews.textFields[UITestGPFAccessibilityIdentifier.telephoneNumberTextFields.rawValue]
        telephonTextField.tap()
        telephonTextField.typeText("+79210000000")
        let dismissKey = app.keyboards.buttons["Dismiss"]
        if dismissKey.exists && dismissKey.isHittable {
            dismissKey.tap()
        }

        let emailTextField = collectionViews.textFields[UITestGPFAccessibilityIdentifier.emailTextFields.rawValue]
        emailTextField.tap()
        emailTextField.typeText("fake@mail.com")
        app.keyboards.buttons["Return"].tap()

        let streetTextField = collectionViews.textFields[UITestGPFAccessibilityIdentifier.streetTextFields.rawValue]
        streetTextField.tap()
        streetTextField.typeText("улица Вавиловых, 8 к1")
        app.keyboards.buttons["Return"].tap()

        let cityTextField = collectionViews.textFields[UITestGPFAccessibilityIdentifier.cityTextFields.rawValue]
        cityTextField.tap()
        cityTextField.typeText("Saint Petersburg")
        app.keyboards.buttons["Return"].tap()

        let postCodeTextField = collectionViews.textFields[UITestGPFAccessibilityIdentifier.postTextFields.rawValue]
        postCodeTextField.tap()
        postCodeTextField.typeText("195257")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let countryTextField = collectionViews.textFields[UITestGPFAccessibilityIdentifier.countryTextFields.rawValue]
        countryTextField.tap()
        countryTextField.typeText("Russia")
        app.keyboards.buttons["Return"].tap()

        app.swipeUp()

        sleep(1)

        app.buttons["pay_button"].tap()

        if app.staticTexts["eCardify"].exists {
            try await loginView()
        } else {
            XCTAssertTrue(app.buttons["Add"].exists)
        }

        sleep(6)

    }

    func loginView() async throws {

        snapshot("login")

        let niceNameTField = app.textFields[UILoginAccessibility.niceNameTF.rawValue]
        niceNameTField.tap()
        niceNameTField.typeText("alif")

        let emailTField = app.textFields[UILoginAccessibility.emailTF.rawValue]
        emailTField.tap()
        emailTField.typeText("uitest@gmail.com")

        try await Task.sleep(nanoseconds: 1_000_000_000)
        app.buttons[UILoginAccessibility.sendEmailButtonTapped.rawValue].tap()

        let codeTField = app.textFields[UILoginAccessibility.codeChangedTF.rawValue]
        codeTField.tap()
        codeTField.typeText("336699")

        try await Task.sleep(nanoseconds: 3_000_000_000)

        app.buttons["pay_button"].tap()

        //XCTAssertTrue(app.buttons["settings_button"].exists)

    }
}
