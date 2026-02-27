import XCTest
import ComposableArchitecture
import ECSharedModels

@testable import SettingsFeature

@MainActor
final class SettingsFeatureTests: XCTestCase {

    // MARK: - onAppear

    func testOnAppear_setsBuildNumber() async {
        let store = TestStore(
            initialState: Settings.State()
        ) {
            Settings()
        } withDependencies: {
            $0.build.number = { 42 }
            $0.build.identifier = { "com.test" }
            $0.keychainClient.readCodable = { _, _, _ in UserOutput.withFirstName }
        }

        await store.send(.onAppear) {
            $0.buildNumber = 42
            $0.currentUser = .withFirstName
        }
    }

    // MARK: - Notification Settings

    func testNotificationAuthorizationResponse_granted() async {
        let store = TestStore(
            initialState: Settings.State()
        ) {
            Settings()
        } withDependencies: {
            $0.remoteNotifications.unregister = {}
        }

        await store.send(.userNotificationAuthorizationResponse(true)) {
            $0.enableNotifications = true
        }
    }

    func testNotificationAuthorizationResponse_denied() async {
        let store = TestStore(
            initialState: Settings.State(enableNotifications: true)
        ) {
            Settings()
        }

        await store.send(.userNotificationAuthorizationResponse(false)) {
            $0.enableNotifications = false
        }
    }

    // MARK: - Restore Purchases

    func testRestoreButtonTapped() async {
        let clock = TestClock()

        let store = TestStore(
            initialState: Settings.State()
        ) {
            Settings()
        } withDependencies: {
            $0.continuousClock = clock
            $0.storeKit.restoreCompletedTransactions = {}
        }

        await store.send(.restoreButtonTapped) {
            $0.destination = .restore(.init())
        }

        await clock.advance(by: .seconds(1))

        await store.receive(\.destination.presented.restore.restoreButtonTapped) {
            $0.destination = .restore(.init(isRestoring: true))
        }
    }

    // MARK: - Leave Review

    func testLeaveReviewButtonTapped() async {
        var openedURL: URL?

        let store = TestStore(
            initialState: Settings.State()
        ) {
            Settings()
        } withDependencies: {
            $0.applicationClient.open = { url, _ in
                openedURL = url
                return true
            }
        }

        await store.send(.leaveUsAReviewButtonTapped)

        XCTAssertNotNil(openedURL)
        XCTAssertTrue(openedURL?.absoluteString.contains("itunes.apple.com") ?? false)
    }

    // MARK: - Log Out

    func testLogOutButtonTapped() async {
        let store = TestStore(
            initialState: Settings.State()
        ) {
            Settings()
        }

        await store.send(.logOutButtonTapped)
        // Currently returns .none
    }

    // MARK: - Our App Links

    func testOurAppLinkButtonTapped_validURL() async {
        var openedURL: URL?

        let store = TestStore(
            initialState: Settings.State()
        ) {
            Settings()
        } withDependencies: {
            $0.applicationClient.open = { url, _ in
                openedURL = url
                return true
            }
        }

        await store.send(.ourAppLinkButtonTapped("https://apps.apple.com/some-app"))

        XCTAssertEqual(openedURL?.absoluteString, "https://apps.apple.com/some-app")
    }

    func testOurAppLinkButtonTapped_invalidURL() async {
        let store = TestStore(
            initialState: Settings.State()
        ) {
            Settings()
        }

        await store.send(.ourAppLinkButtonTapped(""))
        // Invalid URL returns .none
    }
}
