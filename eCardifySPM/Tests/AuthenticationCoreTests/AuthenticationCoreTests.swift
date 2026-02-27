import XCTest
import ComposableArchitecture
import ECSharedModels

@testable import AuthenticationCore

@MainActor
final class AuthenticationCoreTests: XCTestCase {

    // MARK: - Email Validation

    func testEmailValidation_validEmail() async {
        let store = TestStore(initialState: Login.State()) {
            Login()
        }

        await store.send(.set(\.$email, "user@example.com")) {
            $0.email = "user@example.com"
            $0.isEmailValidated = true
        }
    }

    func testEmailValidation_invalidEmail() async {
        let store = TestStore(initialState: Login.State()) {
            Login()
        }

        await store.send(.set(\.$email, "invalid-email")) {
            $0.email = "invalid-email"
            $0.isEmailValidated = false
        }
    }

    func testEmailValidation_emptyEmail() async {
        let store = TestStore(initialState: Login.State()) {
            Login()
        }

        await store.send(.set(\.$email, "")) {
            $0.email = ""
            $0.isEmailValidated = false
        }
    }

    // MARK: - OTP Send

    func testSendOtp_success() async {
        let store = TestStore(
            initialState: Login.State()
        ) {
            Login()
        } withDependencies: {
            $0.neuAuthClient.sendOtp = { _ in
                NeuAuthOtpResponse(message: "Code sent", expiresIn: 900)
            }
        }

        store.state.email = "test@example.com"
        store.state.isEmailValidated = true

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
        let store = TestStore(
            initialState: Login.State()
        ) {
            Login()
        } withDependencies: {
            $0.neuAuthClient.sendOtp = { _ in
                throw NeuAuthError.serverError(statusCode: 500, message: "Server error")
            }
        }

        store.state.email = "test@example.com"
        store.state.isEmailValidated = true

        await store.send(.sendEmailButtonTapped) {
            $0.isLoginRequestInFlight = true
            $0.isEmailValidated = true
        }

        await store.receive(\.otpSendFailed) {
            $0.isLoginRequestInFlight = false
            $0.isValidationCodeIsSend = false
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

        let store = TestStore(
            initialState: Login.State()
        ) {
            Login()
        } withDependencies: {
            $0.neuAuthClient.verifyOtp = { _ in
                NeuAuthResponse(
                    accessToken: "access-token",
                    refreshToken: "refresh-token",
                    user: testUser
                )
            }
            $0.keychainClient.saveOrUpdateCodable = { _, _, _ in }
            $0.build.identifier = { "com.test" }
        }

        store.state.email = "test@example.com"
        store.state.isValidationCodeIsSend = true

        await store.send(.set(\.$code, "123456")) {
            $0.code = "123456"
            $0.isLoginRequestInFlight = true
        }

        await store.receive(\.verificationSuccess) {
            $0.isLoginRequestInFlight = false
            $0.isAuthorized = true
            $0.isUserFirstNameEmpty = false
        }
    }

    func testCodeVerification_shortCode_noRequest() async {
        let store = TestStore(
            initialState: Login.State()
        ) {
            Login()
        }

        store.state.isValidationCodeIsSend = true

        await store.send(.set(\.$code, "123")) {
            $0.code = "123"
        }
        // No effect — code is too short
    }

    func testCodeVerification_notYetSent_noRequest() async {
        let store = TestStore(
            initialState: Login.State()
        ) {
            Login()
        }

        store.state.isValidationCodeIsSend = false

        await store.send(.set(\.$code, "123456")) {
            $0.code = "123456"
        }
        // No effect — OTP was never sent
    }

    func testCodeVerification_failure() async {
        let store = TestStore(
            initialState: Login.State()
        ) {
            Login()
        } withDependencies: {
            $0.neuAuthClient.verifyOtp = { _ in
                throw NeuAuthError.unauthorized("Invalid code")
            }
        }

        store.state.email = "test@example.com"
        store.state.isValidationCodeIsSend = true

        await store.send(.set(\.$code, "000000")) {
            $0.code = "000000"
            $0.isLoginRequestInFlight = true
        }

        await store.receive(\.verificationFailed) {
            $0.isLoginRequestInFlight = false
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

    func testTermsPrivacySheet_nil() async {
        let store = TestStore(initialState: Login.State()) {
            Login()
        }

        await store.send(.termsPrivacySheet(isPresented: .nill))
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
