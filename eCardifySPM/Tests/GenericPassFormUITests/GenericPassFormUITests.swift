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
        await app.launch()

        let collectionViews = await app.collectionViews
        let firstNameTextField = await collectionViews.textFields["*First Name"]
        let lastNameTextField = await collectionViews.textFields["*Last Name"]

        await firstNameTextField.typeText("Jhon")

        await lastNameTextField.tap()
        await lastNameTextField.typeText("Blob")
    }
}
