import XCTest
import ComposableArchitecture
import ECSharedModels
import KeychainClient

@testable import SettingsFeature

@MainActor
final class SettingsFeatureTests: XCTestCase {

    // MARK: - onAppear

    func testOnAppear_setsBuildNumber() async {
        let userData = try! JSONEncoder().encode(UserOutput.withFirstName)
        let store = TestStore(
            initialState: Settings.State()
        ) {
            Settings()
        } withDependencies: {
            $0.build.number = { 42 }
            $0.build.identifier = { "com.test" }
            $0.keychainClient = KeychainClient(
                save: { _, _, _ in },
                read: { _, _ in userData },
                update: { _, _, _ in },
                delete: { _, _ in }
            )
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
        } withDependencies: {
            $0.remoteNotifications.unregister = {}
        }

        await store.send(.userNotificationAuthorizationResponse(false)) {
            $0.enableNotifications = false
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
