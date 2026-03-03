import XCTest
import ComposableArchitecture
import ECSharedModels
import APIClient

@testable import AppFeature
@testable import GenericPassFeature
@testable import KeychainClient

@MainActor
final class AppReducerTests: XCTestCase {

    // MARK: - Helpers

    /// Build a minimal JWT with the given `exp` timestamp.
    /// The signature is fake but the payload is valid JSON for `isAccessTokenExpired()`.
    private func makeTestJWT(exp: TimeInterval) -> String {
        let header = Data("{\"alg\":\"EdDSA\",\"typ\":\"JWT\"}".utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
        let payload = Data("{\"exp\":\(Int(exp)),\"sub\":\"test-sub\"}".utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
        return "\(header).\(payload).fake-signature"
    }

    private var validTokens: RefreshTokenResponse {
        RefreshTokenResponse(
            accessToken: makeTestJWT(exp: Date().timeIntervalSince1970 + 3600),
            refreshToken: "valid-refresh-token"
        )
    }

    private var expiredTokens: RefreshTokenResponse {
        RefreshTokenResponse(
            accessToken: makeTestJWT(exp: Date().timeIntervalSince1970 - 100),
            refreshToken: "expired-refresh-token"
        )
    }

    /// Creates a KeychainClient that returns the given data for reads.
    private func keychainWithTokens(_ tokenData: Data) -> KeychainClient {
        var client = KeychainClient.noop
        client.read = { _, _ in tokenData }
        return client
    }

    // MARK: - validateSession: Not Authorized

    /// When user is not authorized, validateSession does nothing.
    func testValidateSession_notAuthorized_noAction() async {
        let state = AppReducer.State()
        // isAuthorized defaults to false

        let store = TestStore(initialState: state) {
            AppReducer()
        } withDependencies: {
            $0.keychainClient = .noop
            $0.build.identifier = { "com.test" }
        }

        store.exhaustivity = .off

        await store.send(.validateSession)
        // No tokenRefreshFailed should fire — user isn't logged in
    }

    // MARK: - validateSession: Authorized but No Token

    /// When isAuthorized is true but keychain has no token,
    /// validateSession should force re-login via tokenRefreshFailed.
    func testValidateSession_authorizedNoToken_forcesReLogin() async {
        var state = AppReducer.State()
        state.walletState.$isAuthorized.withLock { $0 = true }

        let store = TestStore(initialState: state) {
            AppReducer()
        } withDependencies: {
            // .noop read returns empty Data() → decode as RefreshTokenResponse throws
            $0.keychainClient = .noop
            $0.build.identifier = { "com.test" }
        }

        store.exhaustivity = .off

        await store.send(.validateSession)

        // Should force re-login because keychain has no valid token
        await store.receive(\.tokenRefreshFailed)

        XCTAssertFalse(store.state.walletState.isAuthorized,
            "isAuthorized should be false after token validation failure")
        XCTAssertNotNil(store.state.authState,
            "Login sheet should be presented")
    }

    // MARK: - validateSession: Authorized with Valid Token

    /// When isAuthorized is true and keychain has a valid (non-expired) token,
    /// validateSession should do nothing — session is fine.
    func testValidateSession_authorizedWithValidToken_noAction() async {
        var state = AppReducer.State()
        state.walletState.$isAuthorized.withLock { $0 = true }

        let tokenData = try! JSONEncoder().encode(validTokens)

        let store = TestStore(initialState: state) {
            AppReducer()
        } withDependencies: {
            $0.keychainClient = keychainWithTokens(tokenData)
            $0.build.identifier = { "com.test" }
        }

        store.exhaustivity = .off

        await store.send(.validateSession)
        // No further actions — token is valid, session stays
    }

    // MARK: - validateSession: Expired Token + Refresh Succeeds

    /// When token is expired but refresh succeeds, session stays valid.
    func testValidateSession_expiredToken_refreshSucceeds() async {
        var state = AppReducer.State()
        state.walletState.$isAuthorized.withLock { $0 = true }

        let tokenData = try! JSONEncoder().encode(expiredTokens)

        let store = TestStore(initialState: state) {
            AppReducer()
        } withDependencies: {
            $0.keychainClient = keychainWithTokens(tokenData)
            $0.build.identifier = { "com.test" }
            // neuAuthClient.refreshToken uses testValue → returns valid tokens
        }

        store.exhaustivity = .off

        await store.send(.validateSession)
        // No tokenRefreshFailed — refresh succeeded, user stays authorized

        XCTAssertTrue(store.state.walletState.isAuthorized,
            "isAuthorized should remain true after successful refresh")
        XCTAssertNil(store.state.authState,
            "Login sheet should NOT be presented")
    }

    // MARK: - validateSession: Expired Token + Refresh Fails

    /// When token is expired and refresh also fails, force re-login.
    func testValidateSession_expiredToken_refreshFails_forcesReLogin() async {
        var state = AppReducer.State()
        state.walletState.$isAuthorized.withLock { $0 = true }

        let tokenData = try! JSONEncoder().encode(expiredTokens)

        let store = TestStore(initialState: state) {
            AppReducer()
        } withDependencies: {
            $0.keychainClient = keychainWithTokens(tokenData)
            $0.build.identifier = { "com.test" }
            $0.neuAuthClient.refreshToken = { _ in
                throw NeuAuthError.unauthorized("Token revoked")
            }
        }

        store.exhaustivity = .off

        await store.send(.validateSession)

        await store.receive(\.tokenRefreshFailed)

        XCTAssertFalse(store.state.walletState.isAuthorized)
        XCTAssertNotNil(store.state.authState)
    }

    // MARK: - onAppear triggers validateSession

    /// Verifies that onAppear dispatches validateSession.
    func testOnAppear_triggersValidateSession() async {
        var state = AppReducer.State()
        state.walletState.$isAuthorized.withLock { $0 = true }

        let store = TestStore(initialState: state) {
            AppReducer()
        } withDependencies: {
            $0.keychainClient = .noop
            $0.build.identifier = { "com.test" }
        }

        store.exhaustivity = .off

        await store.send(.onAppear)

        // onAppear should send validateSession, which then sends tokenRefreshFailed
        // (because .noop keychain has no valid token)
        await store.receive(\.validateSession)
        await store.receive(\.tokenRefreshFailed)
    }

    // MARK: - didChangeScenePhase(.active) triggers validateSession

    /// Verifies that scene activation dispatches validateSession.
    func testScenePhaseActive_triggersValidateSession() async {
        var state = AppReducer.State()
        state.walletState.$isAuthorized.withLock { $0 = true }

        let store = TestStore(initialState: state) {
            AppReducer()
        } withDependencies: {
            $0.keychainClient = .noop
            $0.build.identifier = { "com.test" }
        }

        store.exhaustivity = .off

        await store.send(.didChangeScenePhase(.active))

        await store.receive(\.validateSession)
        await store.receive(\.tokenRefreshFailed)
    }

    // MARK: - tokenRefreshFailed clears auth and shows login

    /// Direct test of tokenRefreshFailed behavior.
    func testTokenRefreshFailed_clearsAuthAndShowsLogin() async {
        var state = AppReducer.State()
        state.walletState.$isAuthorized.withLock { $0 = true }

        let store = TestStore(initialState: state) {
            AppReducer()
        } withDependencies: {
            $0.keychainClient = .noop
            $0.build.identifier = { "com.test" }
        }

        store.exhaustivity = .off

        await store.send(.tokenRefreshFailed)

        XCTAssertFalse(store.state.walletState.isAuthorized)
        XCTAssertNotNil(store.state.authState,
            "Login sheet should be presented after tokenRefreshFailed")
    }

    // MARK: - Auth flow routing

    /// Login sheet should only close when AuthenticationCore emits moveToTableView
    /// (which now happens only after keychain persistence succeeds).
    func testAuthMoveToTableView_closesLoginSheet() async {
        let clock = TestClock()

        var state = AppReducer.State()
        state.authState = .init()

        let store = TestStore(initialState: state) {
            AppReducer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.keychainClient = .noop
            $0.build.identifier = { "com.test" }
        }

        store.exhaustivity = .off

        await store.send(.auth(.presented(.moveToTableView)))

        await clock.advance(by: .seconds(1))
        await store.receive(\.isSheetLogin) {
            $0.authState = nil
        }
        await store.receive(\.walletAction)
    }

    /// Regression guard: verificationSuccess alone must not close the login sheet.
    /// When user/access are nil, Login shows an alert but does NOT dismiss.
    func testAuthVerificationSuccess_doesNotCloseLoginSheet() async {
        var state = AppReducer.State()
        state.authState = .init()

        let store = TestStore(initialState: state) {
            AppReducer()
        }

        store.exhaustivity = .off

        let incomplete = SuccessfulLoginResponse(status: "ok", user: nil, access: nil)
        await store.send(.auth(.presented(.verificationSuccess(incomplete))))

        // Login sheet must stay open — verificationSuccess with nil user/access
        // shows an alert, it does NOT trigger moveToTableView.
        XCTAssertNotNil(store.state.authState)
    }
}
