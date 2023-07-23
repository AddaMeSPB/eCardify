import XCTest

@testable import GenericPassFeature

import XCTest

final class GenericPassFormUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
      self.continueAfterFailure = false
      self.app = XCUIApplication()
      app.launchEnvironment = [
        "UITesting": "true"
      ]
    }

    func testFillUpFormContact() async {
        app.launch()

        let collectionViews = app.collectionViews
        let firstNameTextField = collectionViews.textFields["*First Name"]
        let lastNameTextField = collectionViews.textFields["*Last Name"]

        firstNameTextField.typeText("Jhon")

        lastNameTextField.tap()
        lastNameTextField.typeText("Blob")
    }
}
