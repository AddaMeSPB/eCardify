import XCTest
import ComposableArchitecture
import ECSharedModels

@testable import GenericPassFeature

@MainActor
final class WalletPassListTests: XCTestCase {

    // MARK: - Wallet Pass List Response

    func testWpResponse_populatesState() async {
        // Simulate state after onAppear (isLoadingWPL would be true)
        var initialState = WalletPassList.State()
        initialState.isLoadingWPL = true

        let store = TestStore(initialState: initialState) {
            WalletPassList()
        }

        let passes = [WalletPass.mock]

        await store.send(.wpResponse(passes)) {
            let expected = passes.map { WalletPassDetails.State(wp: $0, vCard: $0.vCard) }
            $0.wPass = .init(uniqueElements: expected)
        }

        await store.receive(\.wpLocalDataResponse) {
            let expected = passes
                .filter { $0.isPaid == true }
                .map { WalletPassDetails.State(wp: $0, vCard: $0.vCard) }
            $0.wPassLocal = .init(uniqueElements: expected)
            $0.isLoadingWPL = false
        }
    }

    func testWpResponseFailed() async {
        var state = WalletPassList.State()
        state.isLoadingWPL = true
        let store = TestStore(
            initialState: state
        ) {
            WalletPassList()
        }

        await store.send(.wpResponseFailed("Unable to load cards. Please try again.")) {
            $0.isLoadingWPL = false
            $0.loadError = "Unable to load cards. Please try again."
        }
    }

    // MARK: - Local Data Response

    func testWpLocalDataResponse_filtersPaidOnly() async {
        var state = WalletPassList.State(isActivityIndicatorVisible: false)
        state.isLoadingWPL = true

        let store = TestStore(initialState: state) {
            WalletPassList()
        }

        let paidPass = WalletPass.mock
        let passes = [paidPass]

        await store.send(.wpLocalDataResponse(passes)) {
            let expected = passes
                .filter { $0.isPaid == true }
                .map { WalletPassDetails.State(wp: $0, vCard: $0.vCard) }
            $0.wPassLocal = .init(uniqueElements: expected)
            $0.isLoadingWPL = false
        }
    }

    func testWpLocalDataFailed() async {
        var state = WalletPassList.State()
        state.isLoadingWPL = true

        let store = TestStore(initialState: state) {
            WalletPassList()
        }

        await store.send(.wpLocalDataFailed) {
            $0.isLoadingWPL = false
        }
    }

    // MARK: - Navigation

    func testCreateGenericFormButtonTapped() async {
        var state = WalletPassList.State()
        state.$isAuthorized.withLock { $0 = true }
        // `VCard.empty` is computed (fresh id per access), so the expectation must
        // use the exact draft the reducer reads from `state.vCard` — a new `.empty`
        // here would have a different id and fail the state assertion.
        let draft = state.vCard ?? .empty

        let store = TestStore(initialState: state) {
            WalletPassList()
        }

        await store.send(.createGenericFormButtonTapped) {
            $0.destination = .add(.init(user: nil, vCard: draft))
        }
    }

    /// When not authorized, tapping create should open login sheet instead.
    func testCreateGenericFormButtonTapped_notAuthorized_opensLogin() async {
        let store = TestStore(
            initialState: WalletPassList.State()
        ) {
            WalletPassList()
        }

        await store.send(.createGenericFormButtonTapped)

        await store.receive(\.openSheetLogin)
    }

    // MARK: - Open Sheet Login

    func testOpenSheetLogin() async {
        let store = TestStore(
            initialState: WalletPassList.State()
        ) {
            WalletPassList()
        }

        await store.send(.openSheetLogin(true))
        // Currently returns .none
    }

    // MARK: - Auth Gate: Keychain Failure

    /// When isAuthorized is true but keychain user read fails,
    /// onAppear should clear isAuthorized and trigger login sheet.
    /// This was a real bug: the keychain failure was silently swallowed,
    /// leaving the user stuck on the home page with no token.
    func testOnAppear_keychainUserFails_forcesReLogin() async {
        var state = WalletPassList.State()
        state.$isAuthorized.withLock { $0 = true }

        let store = TestStore(initialState: state) {
            WalletPassList()
        } withDependencies: {
            // .noop read returns empty Data() → readCodable<UserOutput> decode fails
            $0.keychainClient = .noop
            $0.build.identifier = { "com.test" }
        }

        await store.send(.onAppear) {
            $0.$isAuthorized.withLock { $0 = false }
        }

        // Should trigger login sheet via openSheetLogin
        await store.receive(\.openSheetLogin)
    }

    /// When isAuthorized is false and keychain read fails,
    /// onAppear should do nothing (user hasn't logged in yet).
    func testOnAppear_notAuthorized_keychainFails_noAction() async {
        let state = WalletPassList.State()
        // isAuthorized defaults to false

        let store = TestStore(initialState: state) {
            WalletPassList()
        } withDependencies: {
            $0.keychainClient = .noop
            $0.build.identifier = { "com.test" }
        }

        await store.send(.onAppear)
        // No state change, no login trigger
    }

    // MARK: - Add-to-Wallet Failures

    /// Every pass failure must surface an alert. Silent failures hid an
    /// expired signing cert for two years — every pass was un-addable and
    /// the app gave no feedback (support case 2026-10).
    func testAddPassFailed_downloadFailed_showsAlert() async {
        let store = TestStore(initialState: WalletPassList.State()) {
            WalletPassList()
        }

        await store.send(.addPassFailed(.downloadFailed)) {
            $0.alert = AlertState {
                TextState("Download Failed")
            } message: {
                TextState("The pass could not be downloaded. Please check your connection and try again.")
            }
        }

        await store.send(.alert(.dismiss)) {
            $0.alert = nil
        }
    }

    func testAddPassFailed_deviceCannotAddPasses_showsAlert() async {
        let store = TestStore(initialState: WalletPassList.State()) {
            WalletPassList()
        }

        await store.send(.addPassFailed(.deviceCannotAddPasses)) {
            $0.alert = AlertState {
                TextState("Wallet Unavailable")
            } message: {
                TextState("This device can't add passes to Apple Wallet.")
            }
        }
    }

    func testAddPassFailed_invalidPassFile_showsAlert() async {
        let store = TestStore(initialState: WalletPassList.State()) {
            WalletPassList()
        }

        await store.send(.addPassFailed(.invalidPassFile)) {
            $0.alert = AlertState {
                TextState("Invalid Pass")
            } message: {
                TextState("This pass can't be added to Apple Wallet. Please contact support.")
            }
        }
    }

    /// A failure arriving while a sheet is up (e.g. CardCreated → Add to
    /// Wallet) must dismiss the sheet first, wait for the dismissal to
    /// settle, then re-enter to present the alert — otherwise SwiftUI drops
    /// an alert presented in the same update as a sheet dismissal.
    func testAddPassFailed_dismissesPresentedSheet_thenAlerts() async {
        var state = WalletPassList.State()
        state.destination = .cardCreated(.init(walletPass: .mock))

        let store = TestStore(initialState: state) {
            WalletPassList()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
        }

        await store.send(.addPassFailed(.invalidPassFile)) {
            $0.destination = nil
        }

        await store.receive(\.addPassFailed) {
            $0.alert = AlertState {
                TextState("Invalid Pass")
            } message: {
                TextState("This pass can't be added to Apple Wallet. Please contact support.")
            }
        }
    }

    /// A pushed destination (settings) doesn't block alerts — it must NOT
    /// be dismissed when a late failure arrives.
    func testAddPassFailed_keepsPushedDestination() async {
        var state = WalletPassList.State()
        let user = UserOutput.withFirstName
        state.destination = .settings(.init(currentUser: user))

        let store = TestStore(initialState: state) {
            WalletPassList()
        }

        await store.send(.addPassFailed(.downloadFailed)) {
            $0.alert = AlertState {
                TextState("Download Failed")
            } message: {
                TextState("The pass could not be downloaded. Please check your connection and try again.")
            }
        }
    }

    // MARK: - Delete Card

    /// Tapping Delete in a row's context menu must ask for confirmation
    /// first — deletion is destructive and irreversible.
    func testDeleteCardTapped_showsConfirmationAlert() async {
        let pass = WalletPass.mock
        var state = WalletPassList.State()
        state.wPassLocal = [.init(wp: pass, vCard: pass.vCard)]

        let store = TestStore(initialState: state) {
            WalletPassList()
        }

        await store.send(.wPass(.element(id: pass.id, action: .deleteCardButtonTapped))) {
            $0.alert = AlertState {
                TextState("Delete Card")
            } actions: {
                ButtonState(role: .destructive, action: .confirmDelete(id: pass.id)) {
                    TextState("Delete")
                }
                ButtonState(role: .cancel) {
                    TextState("Cancel")
                }
            } message: {
                TextState("This will permanently delete this card, its public page, and its Add to Wallet link. This action cannot be undone.")
            }
        }

        // Cancelling leaves the list untouched.
        await store.send(.alert(.dismiss)) {
            $0.alert = nil
        }
    }

    /// A successful delete removes the row from both the rendered list and
    /// the remote mirror.
    func testWpDeleteResponse_removesRow() async {
        let pass = WalletPass.mock
        var state = WalletPassList.State()
        state.wPass = [.init(wp: pass, vCard: pass.vCard)]
        state.wPassLocal = [.init(wp: pass, vCard: pass.vCard)]

        let store = TestStore(initialState: state) {
            WalletPassList()
        }

        await store.send(.wpDeleteResponse(id: pass.id)) {
            $0.wPass = []
            $0.wPassLocal = []
        }
    }

    /// A failed delete must tell the user — never fail silently.
    func testWpDeleteFailed_showsAlert() async {
        let store = TestStore(initialState: WalletPassList.State()) {
            WalletPassList()
        }

        await store.send(.wpDeleteFailed) {
            $0.alert = AlertState {
                TextState("Error")
            } message: {
                TextState("Unable to delete the card. Please try again.")
            }
        }
    }

    /// A malformed pass id fails fast with the error alert — no request is
    /// attempted. (Real ids are ObjectId hex strings; this is the guard rail.)
    func testConfirmDelete_invalidId_showsErrorAlert() async {
        var state = WalletPassList.State()
        state.alert = AlertState {
            TextState("Delete Card")
        } actions: {
            ButtonState(role: .destructive, action: .confirmDelete(id: "not-a-hex-id")) {
                TextState("Delete")
            }
            ButtonState(role: .cancel) {
                TextState("Cancel")
            }
        } message: {
            TextState("This will permanently delete this card, its public page, and its Add to Wallet link. This action cannot be undone.")
        }

        let store = TestStore(initialState: state) {
            WalletPassList()
        }

        await store.send(.alert(.presented(.confirmDelete(id: "not-a-hex-id")))) {
            $0.alert = nil
        }

        await store.receive(\.wpDeleteFailed) {
            $0.alert = AlertState {
                TextState("Error")
            } message: {
                TextState("Unable to delete the card. Please try again.")
            }
        }
    }
}
