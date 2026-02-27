import Build
import SwiftUI
import APIClient
import LoggerKit
import KeychainClient
import SettingsFeature
import FoundationExtension
import ECSharedModels
import ComposableArchitecture

public enum VerificationCodeCanceable {}

@Reducer
public struct Login {

    @Reducer
    public struct Destination {
        public enum State: Equatable {
            case alert(AlertState<Action.Alert>)
            case termsAndPrivacy(TermsAndPrivacy.State)
        }

        public enum Action: Equatable {
            case termsAndPrivacy(TermsAndPrivacy.Action)

            case alert(Alert)

            public enum Alert {
                case confirm
            }
        }

        public var body: some Reducer<State, Action> {

            Scope(state: \.termsAndPrivacy, action: \.termsAndPrivacy) {
                TermsAndPrivacy()
            }
        }
    }

    @ObservableState
    public struct State: Equatable {

        public init() {}

        @Presents public var destination: Destination.State?

        @Shared(.appStorage("isAuthorized")) public var isAuthorized = false
        @Shared(.appStorage("isUserFirstNameEmpty")) public var isUserFirstNameEmpty = true
        @Shared(.appStorage("isAskPermissionCompleted")) public var isAskPermissionCompleted = false

        public var email: String = ""
        public var code: String = ""

        public var isValidationCodeIsSend = false
        public var isLoginRequestInFlight = false
        public var deviceCheckData: Data?
        public var isEmailValidated: Bool = false

    }

    public enum TermsOrPrivacy {
        case none, terms, privacy
    }

    @CasePathable
    public enum Action: BindableAction, Equatable {
        case destination(PresentationAction<Destination.Action>)
        case binding(BindingAction<State>)
        case onAppear

        case sendEmailButtonTapped
        case otpSendSuccess
        case otpSendFailed(String)
        case verificationSuccess(SuccessfulLoginResponse)
        case verificationFailed(String)


        case termsPrivacySheet(isPresented: TermsOrPrivacy)

        case moveToTableView
    }

    @Dependency(\.mainQueue) var mainQueue
    @Dependency(\.keychainClient) var keychainClient
    @Dependency(\.build) var build
    @Dependency(\.neuAuthClient) var neuAuthClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce(self.core)
            .ifLet(\.$destination, action: \.destination) {
                Destination()
            }
    }


    func core(state: inout State, action: Action) -> Effect<Action> {

        switch action {

            case .onAppear:
                return .none

            case .binding(\.email):

                guard state.email.isEmailValid else {
                    state.isEmailValidated = false
                    return .none
                }

                state.isEmailValidated = true
                return .none

            case .sendEmailButtonTapped:
                state.isLoginRequestInFlight = true
                state.isEmailValidated = true

                let request = NeuAuthOtpRequest(email: state.email.lowercased())

                return .run { send in
                    do {
                        _ = try await neuAuthClient.sendOtp(request)
                        await send(.otpSendSuccess)
                    } catch {
                        sharedLogger.logError(error.localizedDescription)
                        let message: String
                        if let neuAuthError = error as? NeuAuthError {
                            switch neuAuthError {
                            case .rateLimited:
                                message = "Too many attempts. Please wait and try again."
                            case .unauthorized(let msg):
                                message = msg
                            case .serverError(_, let msg):
                                message = msg
                            case .invalidURL:
                                message = "Invalid server configuration."
                            case .unknown:
                                message = "Unable to send verification code. Please check your connection."
                            }
                        } else {
                            message = "Unable to send verification code. Please check your connection."
                        }
                        await send(.otpSendFailed(message))
                    }
                }

            case .binding(\.code):

                guard state.isValidationCodeIsSend else {
                    return .none
                }

                if state.code.count == 6 {

                    state.isLoginRequestInFlight = true

                    let request = NeuAuthOtpVerifyRequest(
                        email: state.email.lowercased(),
                        code: state.code
                    )

                    return .run { send in
                        do {
                            let neuAuthResponse = try await neuAuthClient.verifyOtp(request)
                            await send(.verificationSuccess(neuAuthResponse.toSuccessfulLoginResponse()))
                        } catch {
                            let message: String
                            if let neuAuthError = error as? NeuAuthError {
                                switch neuAuthError {
                                case .rateLimited:
                                    message = "Too many attempts. Please wait and try again."
                                case .unauthorized:
                                    message = "Invalid or expired verification code."
                                case .serverError(_, let msg):
                                    message = msg
                                default:
                                    message = "Verification failed. Please try again."
                                }
                            } else {
                                message = "Verification failed. Please check your connection."
                            }
                            await send(.verificationFailed(message))
                        }
                    }
                }

                return .none

            case .binding:
                return .none

            case .otpSendSuccess:
                state.isLoginRequestInFlight = false
                state.isValidationCodeIsSend = true
                return .none

            case let .otpSendFailed(message):
                state.isLoginRequestInFlight = false
                state.isValidationCodeIsSend = false
                state.destination = .alert(AlertState {
                    TextState("Failed to Send Code")
                } message: {
                    TextState(message)
                })
                return .none

            case let .verificationSuccess(loginRes):

                if loginRes.user == nil || loginRes.access == nil {
                    return .none
                }

                state.isLoginRequestInFlight = false
                state.$isAuthorized.withLock { $0 = true }
                state.$isUserFirstNameEmpty.withLock { $0 = loginRes.user?.fullName == nil }

                return .run { _ in
                    do {
                        try await keychainClient.saveOrUpdateCodable(loginRes.user, .user, build.identifier())
                        try await keychainClient.saveOrUpdateCodable(loginRes.access, .token, build.identifier())
                    } catch {
                        sharedLogger.logError(error.localizedDescription)
                    }
                }

            case let .verificationFailed(message):
                state.isLoginRequestInFlight = false
                state.code = ""
                state.destination = .alert(AlertState {
                    TextState("Verification Failed")
                } message: {
                    TextState(message)
                })
                return .none


            case .destination(.presented(.termsAndPrivacy(.privacy))):
                state.destination = .termsAndPrivacy(.init(wbModel: .init(link: .privacy)))
                return .none


            case .destination(.presented(.termsAndPrivacy(.terms))):
                state.destination = .termsAndPrivacy(.init(wbModel: .init(link: .terms)))
                return .none

            case .destination(.presented(.termsAndPrivacy(.leaveCurrentPageButtonClick))):
                state.destination = nil
                return .none

            case .moveToTableView:
                return .none

            case .destination:
                return .none

            case .termsPrivacySheet(isPresented: let top):
                switch top {
                    case .none:
                        return .none
                    case .terms:
                        state.destination = .termsAndPrivacy(.init(wbModel: .init(link: .terms)))
                        return .none
                    case .privacy:
                        state.destination = .termsAndPrivacy(.init(wbModel: .init(link: .privacy)))
                        return .none
                }

        }

    }
}
