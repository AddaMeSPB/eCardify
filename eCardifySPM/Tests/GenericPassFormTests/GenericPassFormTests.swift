import GRDB
import XCTest
import ComposableArchitecture
import ECSharedModels
@testable import LocalDatabaseClient

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

        // An empty VCard (no name, no org, no position) should NOT be valid
        XCTAssertEqual(store.state.vCard.isVCardValid, false)
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

        await store.send(.binding(.set(\.vCard.position, "CEO & IOS Developer"))) {
            $0.vCard.position = "CEO & IOS Developer"
        }

        await store.send(.binding(.set(\.vCard.contact.firstName, "Jon"))) {
            $0.vCard.contact.firstName = "Jon"
        }

        await store.send(.binding(.set(\.vCard.contact.lastName, "Don"))) {
            $0.vCard.contact.lastName = "Don"
        }

        await store.send(.binding(.set(\.vCard.telephones, [.init(id: telephoneID, type: .work, number: "+79210000000")]))) {
            $0.vCard.telephones[0].id = telephoneID
            $0.vCard.telephones[0].type = .work
            $0.vCard.telephones[0].number = "+79210000000"
        }

        await store.send(.binding(.set(\.vCard.emails, [.init(id: emailID, text: "real@mail.com")]))) {
            $0.vCard.emails[0].id = emailID
            $0.vCard.emails[0].text = "real@mail.com"
        }

        await store.send(
            .binding(.set(
                \.vCard.addresses,
                 [.init(id: addressID, type: .work, postOfficeAddress: nil, extendedAddress: nil, street: "Nevsky pr., 352, 182", locality: "Saint Petersburg", region: "Saint Petersburg", postalCode: "993153", country: "Russia")]
            ))
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

    // MARK: - CreatePass with Keychain Failure

    /// Verifies createPass succeeds when user was set by parent,
    /// even if keychain read fails. This was a real bug: keychain
    /// failure aborted the entire flow silently.
    func testCreatePass_keychainFails_usesParentUser() async {
        // User was injected by parent (WalletPassList) — keychain will fail
        var state = GenericPassForm.State(
            user: .withFirstName,
            vCard: .demo
        )
        state.isFormValid = true
        state.$isAuthorized.withLock { $0 = true }
        // Mark free card as used so we go through buyProduct path
        // (avoids needing localDatabase mock)
        state.$hasUsedFreeCard.withLock { $0 = true }

        let store = TestStore(initialState: state) {
            GenericPassForm()
        } withDependencies: {
            $0.keychainClient = .noop  // .noop read returns empty Data → decode throws
            $0.build.identifier = { "com.test" }
            $0.attachmentS3Client = .happyPath
        }

        // Use non-exhaustive testing: createPass creates a WalletPass with
        // a random ObjectId that we can't predict. We only care that the
        // flow didn't abort and buyProduct was dispatched.
        store.exhaustivity = .off

        // createPass should NOT abort — it should fall through to buyProduct
        await store.send(.createPass)

        // If we get here without a test failure, the keychain failure
        // didn't kill the flow. The action will produce .buyProduct effect.
        await store.receive(\.buyProduct)
        // buyProduct needs products — no products loaded so returns .none

        // Verify the parent-injected user was used (not nil from keychain)
        XCTAssertNotNil(store.state.walletPass)
        XCTAssertEqual(store.state.walletPass?.ownerId, UserOutput.withFirstName.id)
    }

    /// Verifies createPass shows alert when user is truly nil
    /// (not set by parent AND keychain fails).
    func testCreatePass_noUser_showsAlert() async {
        var state = GenericPassForm.State(vCard: .demo)
        state.isFormValid = true
        state.$isAuthorized.withLock { $0 = true }
        // user is nil — not set by parent

        let store = TestStore(initialState: state) {
            GenericPassForm()
        } withDependencies: {
            $0.keychainClient = .noop
            $0.build.identifier = { "com.test" }
            $0.attachmentS3Client = .happyPath
        }

        await store.send(.createPass) {
            $0.alert = AlertState {
                TextState("Error")
            } message: {
                TextState("Please log in to create a card.")
            }
        }
    }

    // MARK: - Free Tier Flow

    /// Verifies that createPass does NOT set hasUsedFreeCard immediately.
    /// The flag should only be set after server confirms (.passResponse).
    /// This was a real bug: setting the flag early caused the UI to flip
    /// from "Create Free Card" button to the payment button while the
    /// API call was still in progress.
    func testCreatePass_freeTier_doesNotSetFlagEarly() async {
        var state = GenericPassForm.State(
            user: .withFirstName,
            vCard: .demo
        )
        state.isFormValid = true
        state.$isAuthorized.withLock { $0 = true }
        // hasUsedFreeCard defaults to false → isEligibleForFreeCard = true

        let store = TestStore(initialState: state) {
            GenericPassForm()
        } withDependencies: {
            $0.keychainClient = .noop
            $0.build.identifier = { "com.test" }
            $0.attachmentS3Client = .happyPath
            $0.localDatabase = .empty()
        }

        store.exhaustivity = .off

        await store.send(.createPass)

        // After createPass, the free card flag must still be false.
        // If it's true here, the UI flipped to payment prematurely.
        XCTAssertFalse(store.state.hasUsedFreeCard,
            "hasUsedFreeCard must not be set before server confirms")
        XCTAssertTrue(store.state.isEligibleForFreeCard,
            "UI should still show free card button during API call")

        // saveToServer will fire next (API call), but we can't mock
        // apiClient.request easily, so we verify the state assertion above.
    }

    /// Verifies that .passResponse sets hasUsedFreeCard when it was a free card.
    func testPassResponse_freeTier_setsFlagAfterServerConfirms() async {
        var state = GenericPassForm.State(
            user: .withFirstName,
            vCard: .demo
        )
        state.isFormValid = true
        state.$isAuthorized.withLock { $0 = true }
        // Simulate: createPass already ran, walletPass was created
        state.walletPass = WalletPass(
            _id: .init(),
            ownerId: UserOutput.withFirstName.id,
            vCard: .demo,
            colorPalette: .default,
            isPaid: true
        )

        let store = TestStore(initialState: state) {
            GenericPassForm()
        } withDependencies: {
            $0.attachmentS3Client = .happyPath
            $0.localDatabase = .empty()
        }

        store.exhaustivity = .off

        // Server responds successfully
        await store.send(.passResponse(.init(urlString: "https://example.com/pass.pkpass")))

        // NOW the flag should be set
        XCTAssertTrue(store.state.hasUsedFreeCard,
            "hasUsedFreeCard should be set after server confirms")
        XCTAssertFalse(store.state.isEligibleForFreeCard,
            "User should no longer be eligible for free card")
    }

    /// Verifies that .passResponseFailed shows an error alert with retry.
    /// This was a real bug: the API failure was completely silent — no error,
    /// no dismiss, user stuck on the form page with no feedback.
    func testPassResponseFailed_showsAlertWithRetry() async {
        var state = GenericPassForm.State(
            user: .withFirstName,
            vCard: .demo
        )
        state.isActivityIndicatorVisible = true  // simulating in-progress save

        let store = TestStore(initialState: state) {
            GenericPassForm()
        } withDependencies: {
            $0.attachmentS3Client = .happyPath
        }

        await store.send(.passResponseFailed(reason: "Cannot connect to server.")) {
            $0.isActivityIndicatorVisible = false
            $0.alert = AlertState {
                TextState("Error")
            } actions: {
                ButtonState(role: .cancel) {
                    TextState("OK")
                }
                ButtonState(action: .retrySave) {
                    TextState("Retry")
                }
            } message: {
                TextState("Failed to save your card. Cannot connect to server.")
            }
        }
    }

    /// Verifies that tapping Retry in the error alert retriggers saveToServer.
    func testPassResponseFailed_retryTriggeresSaveToServer() async {
        var state = GenericPassForm.State(
            user: .withFirstName,
            vCard: .demo
        )
        state.walletPass = WalletPass(
            _id: .init(),
            ownerId: UserOutput.withFirstName.id,
            vCard: .demo,
            colorPalette: .default,
            isPaid: true
        )
        // Set up the alert state (as if passResponseFailed already fired)
        state.alert = AlertState {
            TextState("Error")
        } actions: {
            ButtonState(role: .cancel) {
                TextState("OK")
            }
            ButtonState(action: .retrySave) {
                TextState("Retry")
            }
        } message: {
            TextState("Failed to save your card. Cannot connect to server.")
        }

        let store = TestStore(initialState: state) {
            GenericPassForm()
        } withDependencies: {
            $0.keychainClient = .noop
            $0.build.identifier = { "com.test" }
            $0.attachmentS3Client = .happyPath
        }

        store.exhaustivity = .off

        // Simulate alert retry button tapped
        await store.send(.alert(.presented(.retrySave)))

        // Should trigger saveToServer
        await store.receive(\.saveToServer)
    }

    /// Verifies that the burned hasUsedFreeCard flag is recovered on onAppear
    /// when no paid cards exist in local database.
    func testOnAppear_recovers_burnedFreeCardFlag() async {
        var state = GenericPassForm.State(
            user: .withFirstName,
            vCard: .demo
        )
        // Simulate burned flag from old bug
        state.$hasUsedFreeCard.withLock { $0 = true }

        let store = TestStore(initialState: state) {
            GenericPassForm()
        } withDependencies: {
            $0.keychainClient = .noop
            $0.build.identifier = { "com.test" }
            $0.attachmentS3Client = .happyPath
            $0.storeKit = .noop
            // Empty database — no paid cards exist
            $0.localDatabase = .empty()
        }

        store.exhaustivity = .off

        XCTAssertTrue(store.state.hasUsedFreeCard, "Flag should start burned")

        await store.send(.onAppear)

        // Should receive resetFreeCardFlag since no paid cards exist
        await store.receive(\.resetFreeCardFlag)

        XCTAssertFalse(store.state.hasUsedFreeCard,
            "Flag should be recovered — no paid cards exist")
        XCTAssertTrue(store.state.isEligibleForFreeCard,
            "User should be eligible for free card again")
    }

    // MARK: - Duplicate-name warning

    /// Saving a NEW card (different vCard id) under a name the user already
    /// has must warn — matching case- and whitespace-insensitively.
    func testCreatePass_duplicateName_showsWarning() async {
        var existingVCard = VCard.empty
        existingVCard.contact.firstName = "Jane"
        existingVCard.contact.lastName = "Smith"
        let existingPass = WalletPass(_id: .init(), ownerId: .init(), vCard: existingVCard)

        // Different capitalization + stray whitespace must still match.
        var draft = VCard.empty
        draft.contact.firstName = " jane"
        draft.contact.lastName = "SMITH "

        var state = GenericPassForm.State(
            isFormValid: true,
            user: .withFirstName,
            vCard: draft,
            existingCards: [existingPass]
        )
        state.$isAuthorized.withLock { $0 = true }

        let store = TestStore(initialState: state) {
            GenericPassForm()
        } withDependencies: {
            $0.keychainClient = .noop
            $0.build.identifier = { "com.test" }
        }

        await store.send(.createPass) {
            $0.alert = AlertState {
                TextState("Card Already Exists")
            } actions: {
                ButtonState(action: .editExistingCard(vCardID: existingVCard.id)) {
                    TextState("Edit Existing Card")
                }
                ButtonState(action: .createAnyway) {
                    TextState("Create Anyway")
                }
                ButtonState(role: .cancel) {
                    TextState("Cancel")
                }
            } message: {
                TextState("You already have a card for Jane Smith. Edit it instead?")
            }
        }
    }

    /// "Edit Existing Card" loads the matching card into the form, so the
    /// save carries its vCard id and the server updates it in place.
    func testEditExistingCard_loadsExistingCardIntoForm() async {
        var existingVCard = VCard.empty
        existingVCard.contact.firstName = "Jane"
        existingVCard.contact.lastName = "Smith"
        existingVCard.position = "CEO"
        let existingPass = WalletPass(_id: .init(), ownerId: .init(), vCard: existingVCard)

        var draft = VCard.empty
        draft.contact.firstName = "Jane"
        draft.contact.lastName = "Smith"

        var state = GenericPassForm.State(
            user: .withFirstName,
            vCard: draft,
            existingCards: [existingPass]
        )
        state.alert = AlertState {
            TextState("Card Already Exists")
        } actions: {
            ButtonState(action: .editExistingCard(vCardID: existingVCard.id)) {
                TextState("Edit Existing Card")
            }
            ButtonState(action: .createAnyway) {
                TextState("Create Anyway")
            }
            ButtonState(role: .cancel) {
                TextState("Cancel")
            }
        } message: {
            TextState("You already have a card for Jane Smith. Edit it instead?")
        }

        let store = TestStore(initialState: state) {
            GenericPassForm()
        }

        await store.send(.alert(.presented(.editExistingCard(vCardID: existingVCard.id)))) {
            $0.alert = nil
            $0.editingExistingPass = existingPass
            $0.vCard = existingVCard
            $0.colorPalette = existingPass.colorPalette
        }
    }

    /// Saving in edit mode must keep the existing pass identity (_id) and go
    /// straight to the server save — no purchase, no free-card consumption.
    func testCreatePass_editingExistingCard_skipsPurchaseAndKeepsIdentity() async {
        var existingVCard = VCard.empty
        existingVCard.contact.firstName = "Jane"
        existingVCard.contact.lastName = "Smith"
        let existingPass = WalletPass(
            _id: .init(),
            ownerId: .init(),
            vCard: existingVCard,
            isPaid: true,
            publicSlug: "jane-smith"
        )

        var state = GenericPassForm.State(
            isFormValid: true,
            user: .withFirstName,
            vCard: existingVCard,
            existingCards: [existingPass]
        )
        state.editingExistingPass = existingPass
        state.$isAuthorized.withLock { $0 = true }
        // A user with no free card left: the NEW-card path would go through
        // .buyProduct here — edit mode must not.
        state.$hasUsedFreeCard.withLock { $0 = true }

        let store = TestStore(initialState: state) {
            GenericPassForm()
        } withDependencies: {
            $0.keychainClient = .noop
            $0.build.identifier = { "com.test" }
            $0.localDatabase = .empty()
        }
        store.exhaustivity = .off

        await store.send(.createPass)

        // Straight to the server save — .buyProduct would mean a double charge.
        await store.receive(\.saveToServer)

        XCTAssertEqual(store.state.walletPass?._id, existingPass._id,
            "Edit must keep the pass _id so the server updates the row in place")
        XCTAssertEqual(store.state.walletPass?.publicSlug, "jane-smith",
            "Edit must keep the public slug so the card's URL survives")
    }

    // MARK: - Local database migration

    /// Production databases were created WITHOUT the publicSlug column (nil
    /// slugs were silently omitted by Codable persistence, which is why saves
    /// used to work). The upgrade path must add the column, keep legacy rows,
    /// and allow saving a pass WITH a slug — the edit-existing flow does that.
    /// DEBUG's eraseDatabaseOnSchemaChange never exercises this, hence an
    /// explicit test.
    func testMigration_oldDatabaseGainsPublicSlugColumn() async throws {
        let dbQueue = try DatabaseQueue()

        // Reproduce the ORIGINAL on-disk schema and a legacy row.
        var legacySchema = DatabaseMigrator()
        legacySchema.registerMigration("createWalletPass") { db in
            try db.create(table: "wallet_passes") { t in
                t.column("_id", .text).notNull().unique()
                t.primaryKey(["_id"])
                t.column("ownerId", .text)
                t.column("vCard", .text).notNull()
                t.column("colorPalette", .text).notNull()
                t.column("isPaid", .boolean).notNull().defaults(to: false)
                t.column("isDataSavedOnServer", .boolean).notNull().defaults(to: false)
                t.column("createdAt", .datetime)
                t.column("updatedAt", .datetime)
            }
        }
        try legacySchema.migrate(dbQueue)
        try await dbQueue.write { db in
            try db.execute(
                sql: "INSERT INTO wallet_passes (_id, ownerId, vCard, colorPalette) VALUES (?, ?, ?, ?)",
                arguments: ["6ad000000000000000000001", "6ad000000000000000000002", "{}", "{}"]
            )
        }

        // Opening AppDatabase runs the real migrator over the legacy database.
        let appDatabase = try AppDatabase(dbQueue)

        // The legacy row survived (no erase, no failed migration)…
        let legacyCount = try await dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM wallet_passes")
        }
        XCTAssertEqual(legacyCount, 1, "legacy row must survive the migration")

        // …and a pass WITH a public slug now saves and round-trips.
        let pass = WalletPass(
            _id: .init(),
            ownerId: .init(),
            vCard: .empty,
            isPaid: true,
            publicSlug: "jane-smith"
        )
        try await appDatabase.create(wp: pass)
        let fetched = try await appDatabase.findBy(id: pass.id)
        XCTAssertEqual(fetched?.publicSlug, "jane-smith",
            "a pass with a slug must save into the migrated schema")
    }

    /// "Create Anyway" marks the save confirmed and retries createPass —
    /// the duplicate check must not fire a second time.
    func testCreateAnyway_setsFlagAndRetries() async {
        var draft = VCard.empty
        draft.contact.firstName = "Jane"
        draft.contact.lastName = "Smith"

        // isFormValid=false stops the retried createPass before any side
        // effects — this test only asserts the confirm-and-retry wiring.
        var state = GenericPassForm.State(
            isFormValid: false,
            user: .withFirstName,
            vCard: draft
        )
        state.$isAuthorized.withLock { $0 = true }
        state.alert = AlertState {
            TextState("Card Already Exists")
        } actions: {
            ButtonState(action: .createAnyway) {
                TextState("Create Anyway")
            }
        } message: {
            TextState("You already have a card for Jane Smith. Edit it instead?")
        }

        let store = TestStore(initialState: state) {
            GenericPassForm()
        } withDependencies: {
            $0.keychainClient = .noop
            $0.build.identifier = { "com.test" }
        }

        await store.send(.alert(.presented(.createAnyway))) {
            $0.alert = nil
            $0.duplicateSaveConfirmed = true
        }

        await store.receive(\.createPass)
    }

    /// Re-saving the SAME card (matching vCard id) must not warn — and even
    /// without edit mode set (sheet dismissed mid-edit, form reopened with
    /// the persisted draft), the save must adopt the existing card's identity
    /// instead of charging for a create the server would merge anyway.
    func testCreatePass_resaveSameCard_noWarning_adoptsEditMode() async {
        var existingVCard = VCard.empty
        existingVCard.contact.firstName = "Jane"
        existingVCard.contact.lastName = "Smith"
        let existingPass = WalletPass(
            _id: .init(),
            ownerId: .init(),
            vCard: existingVCard,
            isPaid: true,
            publicSlug: "jane-smith"
        )

        // A second card with the SAME name but a different vCard id (the
        // "Create Anyway" outcome) must not re-trigger the warning when the
        // first card is re-saved.
        var secondVCard = VCard.empty
        secondVCard.contact.firstName = "Jane"
        secondVCard.contact.lastName = "Smith"
        let secondPass = WalletPass(_id: .init(), ownerId: .init(), vCard: secondVCard, isPaid: true)

        var state = GenericPassForm.State(
            isFormValid: true,
            user: .withFirstName,
            vCard: existingVCard, // same vCard id as the existing card
            existingCards: [existingPass, secondPass]
        )
        state.$isAuthorized.withLock { $0 = true }
        // No free card left: the NEW-card path would mean .buyProduct here.
        state.$hasUsedFreeCard.withLock { $0 = true }

        let store = TestStore(initialState: state) {
            GenericPassForm()
        } withDependencies: {
            $0.keychainClient = .noop
            $0.build.identifier = { "com.test" }
            $0.localDatabase = .empty()
        }
        store.exhaustivity = .off

        await store.send(.createPass)
        await store.receive(\.saveToServer)

        XCTAssertNil(store.state.alert,
            "Re-saving the same card must not trigger the duplicate warning")
        XCTAssertEqual(store.state.editingExistingPass?._id, existingPass._id,
            "Re-save of an existing card must adopt edit mode")
        XCTAssertEqual(store.state.walletPass?._id, existingPass._id,
            "Re-save must keep the existing pass _id — not mint a new one")
    }
}
