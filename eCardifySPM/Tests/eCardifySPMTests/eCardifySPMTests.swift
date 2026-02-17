import XCTest
@testable import eCardifySPM

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

    func testFillUpFormContact() async {
        app.launch()
        app.buttons["plus.square.fill"].tap()

        let collectionViews = app.collectionViews

        let firstNameTextField = collectionViews.textFields["*First Name"]
        let lastNameTextField = collectionViews.textFields["*Last Name"]
        let telephonTextField = collectionViews.textFields["telephone_number"]
        let emailTextField = collectionViews.textFields["*Email"]
        let postOfficeTextField = collectionViews.textFields["*PostOffice"]
        let streetTextField = collectionViews.textFields["*Street"]
        let cityTextField = collectionViews.textFields["*City"]
        let regionStateTextField = collectionViews.textFields["*Region/State"]
        let postCodeTextField = collectionViews.textFields["*Post Code"]
        let countryTextField = collectionViews.textFields["*Country"]

        firstNameTextField.tap()
        firstNameTextField.typeText("Jhon")

        lastNameTextField.tap()
        lastNameTextField.typeText("Blob")

        telephonTextField.tap()
        telephonTextField.typeText("")

        emailTextField.tap()
        emailTextField.typeText("")

        postOfficeTextField.tap()
        postOfficeTextField.typeText("улица Вавиловых, 8 к1")

        streetTextField.tap()
        streetTextField.typeText("")

        cityTextField.tap()
        cityTextField.typeText("Saint Petersburg")

        regionStateTextField.tap()
        regionStateTextField.typeText("Saint Petersburg")

        postCodeTextField.tap()
        postCodeTextField.typeText("195257")

        countryTextField.tap()
        countryTextField.typeText("Russia")


    }
}

