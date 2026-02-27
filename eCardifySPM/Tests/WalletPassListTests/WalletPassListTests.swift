import XCTest
import ComposableArchitecture
import ECSharedModels

@testable import GenericPassFeature

@MainActor
final class WalletPassListTests: XCTestCase {

    // MARK: - Wallet Pass List Response

    func testWpResponse_populatesState() async {
        let store = TestStore(
            initialState: WalletPassList.State()
        ) {
            WalletPassList()
        }

        let passes = [WalletPass.demo]

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
        let store = TestStore(
            initialState: WalletPassList.State()
        ) {
            WalletPassList()
        }

        await store.send(.wpResponseFailed)
        // No state change
    }

    // MARK: - Local Data Response

    func testWpLocalDataResponse_filtersPaidOnly() async {
        let store = TestStore(
            initialState: WalletPassList.State(isActivityIndicatorVisible: false)
        ) {
            WalletPassList()
        }

        store.state.isLoadingWPL = true

        let paidPass = WalletPass.demo
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
        let store = TestStore(
            initialState: WalletPassList.State()
        ) {
            WalletPassList()
        }

        store.state.isLoadingWPL = true

        await store.send(.wpLocalDataFailed) {
            $0.isLoadingWPL = false
        }
    }

    // MARK: - Navigation

    func testCreateGenericFormButtonTapped() async {
        let store = TestStore(
            initialState: WalletPassList.State()
        ) {
            WalletPassList()
        }

        await store.send(.createGenericFormButtonTapped) {
            $0.destination = .add(.init(vCard: .empty))
        }
    }

    func testDismissAddGenericFormButtonTapped() async {
        let store = TestStore(
            initialState: WalletPassList.State()
        ) {
            WalletPassList()
        }

        store.state.destination = .add(.init(vCard: .empty))

        await store.send(.dismissAddGenericFormButtonTapped) {
            $0.destination = nil
        }
    }

    func testNavigateSettingsButtonTapped_withUser() async {
        let store = TestStore(
            initialState: WalletPassList.State()
        ) {
            WalletPassList()
        }

        store.state.user = .withFirstName

        await store.send(.navigateSettingsButtonTapped) {
            $0.destination = .settings(.init(currentUser: .withFirstName))
        }
    }

    func testNavigateSettingsButtonTapped_noUser() async {
        let store = TestStore(
            initialState: WalletPassList.State()
        ) {
            WalletPassList()
        }

        store.state.user = nil

        await store.send(.navigateSettingsButtonTapped)
        // No navigation when user is nil
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
}
