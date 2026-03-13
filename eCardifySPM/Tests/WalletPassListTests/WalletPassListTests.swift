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

        let store = TestStore(initialState: state) {
            WalletPassList()
        }

        await store.send(.createGenericFormButtonTapped) {
            $0.destination = .add(.init(user: nil, vCard: .empty))
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
}
