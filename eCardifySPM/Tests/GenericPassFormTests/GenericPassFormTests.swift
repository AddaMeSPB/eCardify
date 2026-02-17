import XCTest
import ComposableArchitecture

@testable import GenericPassFeature

@MainActor
final class GenericPassFormTests: XCTestCase {

    func testFillUpIsValidFormFailed() async {
        let store = TestStore(
            initialState: GenericPassForm.State(vCard: .init(contact: .empty, formattedName: "", organization: "", position: "", website: "", socialMedia: .empty))
        ) {
            GenericPassForm()
        } withDependencies: {
            $0.attachmentS3Client = .happyPath
        }

        XCTAssertEqual(store.state.vCard.isVCardValid, true)

    }

    func testFillUpIsValidForm() async {

        let store = TestStore(
            initialState: GenericPassForm.State(vCard: .empty)
        ) {
            GenericPassForm()
        } withDependencies: {
            $0.attachmentS3Client = .happyPath
        }

        let telephoneID = UUID()
        let emailID = UUID()
        let addressID = UUID()

        // You must use .send(.set(\.$vCard, …))
        await store.send(.set(\.$vCard.position, "CEO & IOS Developer")) {
            $0.vCard.position = "CEO & IOS Developer"
        }

        await store.send(.set(\.$vCard.contact.firstName, "Jon")) {
            $0.vCard.contact.firstName = "Jon"
        }

        await store.send(.set(\.$vCard.contact.lastName, "Don")) {
            $0.vCard.contact.lastName = "Don"
        }


        await store.send(.set(\.$vCard.telephones, [.init(id: telephoneID,type: .work, number: "+79210000000")])) {
            $0.vCard.telephones[0].id = telephoneID
            $0.vCard.telephones[0].type = .work
            $0.vCard.telephones[0].number = "+79210000000"
        }


        await store.send(.set(\.$vCard.emails, [.init(id: emailID, text: "real@mail.com")])) {
            $0.vCard.emails[0].id = emailID
            $0.vCard.emails[0].text = "real@mail.com"
        }


        await store.send(
            .set(
                \.$vCard.addresses,
                 [.init(id: addressID, type: .work, postOfficeAddress: nil, extendedAddress: nil, street: "Nevsky pr., 352, 182", locality: "Saint Petersburg", region: "Saint Petersburg", postalCode: "993153", country: "Russia")]
            )
        ) {
            $0.vCard.addresses[0].id = addressID
            $0.vCard.addresses[0].street = "Nevsky pr., 352, 182"
            $0.vCard.addresses[0].locality = "Saint Petersburg"
            $0.vCard.addresses[0].region = "Saint Petersburg"
            $0.vCard.addresses[0].postalCode = "993153"
            $0.vCard.addresses[0].country = "Russia"
        }

        XCTAssertEqual(store.state.vCard.isVCardValid, true)

    }

}
