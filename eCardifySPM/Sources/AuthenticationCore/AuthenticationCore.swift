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

            case login(Login.Action)
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

        public static func == (lhs: State, rhs: State) -> Bool {
            return lhs.isAuthorized == rhs.isAuthorized
        }

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
        case nill, terms, privacy
    }

    @CasePathable
    public enum Action: BindableAction, Equatable {
        case destination(PresentationAction<Destination.Action>)
        case binding(BindingAction<State>)
        case onAppear

        case sendEmailButtonTapped
        case otpSendResponse(TaskResult<NeuAuthOtpResponse>)
        case verificationResponse(TaskResult<SuccessfulLoginResponse>)


        case termsPrivacySheet(isPresented: TermsOrPrivacy)

        case moveToTableView
    }

    public enum AlertAction: Equatable {}

    @Dependency(\.mainQueue) var mainQueue
    @Dependency(\.keychainClient) var keychainClient
    @Dependency(\.build) var build
    @Dependency(\.neuAuthClient) var neuAuthClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce(self.core)
    }


    func core(state: inout State, action: Action) -> Effect<Action> {

        switch action {

            case .onAppear:
                // @Shared properties auto-sync with AppStorage — no manual read needed
                if state.isAuthorized {
                    if !state.isAskPermissionCompleted {
                        return .none
                    }
                }

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
                    await send(.otpSendResponse(
                        await TaskResult {
                            try await neuAuthClient.sendOtp(request)
                        }
                    ))
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
                        await send(.verificationResponse(
                            await TaskResult {
                                let neuAuthResponse = try await neuAuthClient.verifyOtp(request)
                                // Map NeuAuth response to existing app model
                                return neuAuthResponse.toSuccessfulLoginResponse()
                            }
                        ))
                    }
                }

                return .none

            case .binding:
                return .none

            case .otpSendResponse(.success):
                state.isLoginRequestInFlight = false
                state.isValidationCodeIsSend = true

                return .none

            case .otpSendResponse(.failure(let error)):
                state.isLoginRequestInFlight = false
                state.isValidationCodeIsSend = false
                sharedLogger.logError(error.localizedDescription)
                return .none

            case let .verificationResponse(.success(loginRes)):

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

            case .verificationResponse(.failure(_)):
                // state.alert = .init(title: TextState("Please try again!") )
                // send this for logs .init(title: TextState(error.description))
                state.isLoginRequestInFlight = false

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
                    case .nill:
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
