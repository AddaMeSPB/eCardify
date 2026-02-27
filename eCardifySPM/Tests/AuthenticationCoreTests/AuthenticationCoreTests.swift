import XCTest
import ComposableArchitecture
import ECSharedModels
import APIClient

@testable import AuthenticationCore

@MainActor
final class AuthenticationCoreTests: XCTestCase {

    // MARK: - Email Validation

    func testEmailValidation_validEmail() async {
        let store = TestStore(initialState: Login.State()) {
            Login()
        }

        await store.send(.binding(.set(\.email, "user@example.com"))) {
            $0.email = "user@example.com"
            $0.isEmailValidated = true
        }
    }

    func testEmailValidation_invalidEmail() async {
        let store = TestStore(initialState: Login.State()) {
            Login()
        }

        await store.send(.binding(.set(\.email, "invalid-email"))) {
            $0.email = "invalid-email"
            $0.isEmailValidated = false
        }
    }

    func testEmailValidation_emptyEmail() async {
        let store = TestStore(initialState: Login.State()) {
            Login()
        }

        await store.send(.binding(.set(\.email, ""))) {
            $0.email = ""
            $0.isEmailValidated = false
        }
    }

    // MARK: - OTP Send

    func testSendOtp_success() async {
        var state = Login.State()
        state.email = "test@example.com"
        state.isEmailValidated = true

        let store = TestStore(initialState: state) {
            Login()
        } withDependencies: {
            $0.neuAuthClient.sendOtp = { _ in
                NeuAuthOtpResponse(message: "Code sent", expiresIn: 900)
            }
        }

        await store.send(.sendEmailButtonTapped) {
            $0.isLoginRequestInFlight = true
            $0.isEmailValidated = true
        }

        await store.receive(\.otpSendSuccess) {
            $0.isLoginRequestInFlight = false
            $0.isValidationCodeIsSend = true
        }
    }

    func testSendOtp_failure() async {
        var state = Login.State()
        state.email = "test@example.com"
        state.isEmailValidated = true

        let store = TestStore(initialState: state) {
            Login()
        } withDependencies: {
            $0.neuAuthClient.sendOtp = { _ in
                throw NeuAuthError.serverError(statusCode: 500, message: "Server error")
            }
        }

        await store.send(.sendEmailButtonTapped) {
            $0.isLoginRequestInFlight = true
            $0.isEmailValidated = true
        }

        await store.receive(\.otpSendFailed) {
            $0.isLoginRequestInFlight = false
            $0.isValidationCodeIsSend = false
            $0.destination = .alert(AlertState {
                TextState("Failed to Send Code")
            } message: {
                TextState("Server error")
            })
        }
    }

    // MARK: - OTP Verification

    func testCodeVerification_success() async {
        let testUser = NeuAuthUser(
            id: UUID(),
            email: "test@example.com",
            emailVerified: true,
            displayName: "Test User",
            roles: ["user"],
            tenantId: UUID()
        )

        var state = Login.State()
        state.email = "test@example.com"
        state.isValidationCodeIsSend = true

        let store = TestStore(initialState: state) {
            Login()
        } withDependencies: {
            $0.neuAuthClient.verifyOtp = { _ in
                NeuAuthResponse(
                    accessToken: "access-token",
                    refreshToken: "refresh-token",
                    user: testUser
                )
            }
            $0.keychainClient = .noop
            $0.build.identifier = { "com.test" }
        }

        await store.send(.binding(.set(\.code, "123456"))) {
            $0.code = "123456"
            $0.isLoginRequestInFlight = true
        }

        await store.receive(\.verificationSuccess) {
            $0.isLoginRequestInFlight = false
            $0.$isAuthorized.withLock { $0 = true }
            $0.$isUserFirstNameEmpty.withLock { $0 = false }
        }
    }

    func testCodeVerification_shortCode_noRequest() async {
        var state = Login.State()
        state.isValidationCodeIsSend = true

        let store = TestStore(initialState: state) {
            Login()
        }

        await store.send(.binding(.set(\.code, "123"))) {
            $0.code = "123"
        }
        // No effect — code is too short
    }

    func testCodeVerification_notYetSent_noRequest() async {
        let store = TestStore(initialState: Login.State()) {
            Login()
        }

        await store.send(.binding(.set(\.code, "123456"))) {
            $0.code = "123456"
        }
        // No effect — OTP was never sent
    }

    func testCodeVerification_failure() async {
        var state = Login.State()
        state.email = "test@example.com"
        state.isValidationCodeIsSend = true

        let store = TestStore(initialState: state) {
            Login()
        } withDependencies: {
            $0.neuAuthClient.verifyOtp = { _ in
                throw NeuAuthError.unauthorized("Invalid code")
            }
        }

        await store.send(.binding(.set(\.code, "000000"))) {
            $0.code = "000000"
            $0.isLoginRequestInFlight = true
        }

        await store.receive(\.verificationFailed) {
            $0.isLoginRequestInFlight = false
            $0.code = ""
            $0.destination = .alert(AlertState {
                TextState("Verification Failed")
            } message: {
                TextState("Invalid or expired verification code.")
            })
        }
    }

    // MARK: - Terms & Privacy

    func testTermsSheet() async {
        let store = TestStore(initialState: Login.State()) {
            Login()
        }

        await store.send(.termsPrivacySheet(isPresented: .terms)) {
            $0.destination = .termsAndPrivacy(.init(wbModel: .init(link: .terms)))
        }
    }

    func testPrivacySheet() async {
        let store = TestStore(initialState: Login.State()) {
            Login()
        }

        await store.send(.termsPrivacySheet(isPresented: .privacy)) {
            $0.destination = .termsAndPrivacy(.init(wbModel: .init(link: .privacy)))
        }
    }

    func testTermsPrivacySheet_none() async {
        let store = TestStore(initialState: Login.State()) {
            Login()
        }

        await store.send(.termsPrivacySheet(isPresented: .none))
        // No state change
    }

    // MARK: - onAppear

    func testOnAppear_notAuthorized() async {
        let store = TestStore(initialState: Login.State()) {
            Login()
        }

        await store.send(.onAppear)
        // No effects when not authorized
    }
}
