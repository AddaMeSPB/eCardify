//
//  eCardifyUITestsLaunchTests.swift
//  eCardifyUITests
//
//  Created by Saroar Khandoker on 22.07.2023.
//

import XCTest

final class eCardifyUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

@MainActor
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
