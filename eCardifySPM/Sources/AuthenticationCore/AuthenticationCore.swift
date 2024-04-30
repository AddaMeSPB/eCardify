import Build
import Combine
import SwiftUI
import APIClient
import LoggerKit
import KeychainClient
import SettingsFeature
import UserDefaultsClient
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

        public var niceName = ""
        public var email: String = ""
        public var code: String = ""

        public var emailLoginInput: EmailLoginInput?
        public var emailLoginOutput: EmailLoginOutput?
        public var isValidationCodeIsSend = false
        public var isLoginRequestInFlight = false
        public var isAuthorized: Bool = false
        public var isUserFirstNameEmpty: Bool = true
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
        case loginResponse(TaskResult<EmailLoginOutput>)
        case verificationResponse(TaskResult<SuccessfulLoginResponse>)


        case termsPrivacySheet(isPresented: TermsOrPrivacy)

        case moveToTableView
    }

    public enum AlertAction: Equatable {}

    @Dependency(\.mainQueue) var mainQueue
    @Dependency(\.userDefaults) var userDefaults
    @Dependency(\.keychainClient) var keychainClient
    @Dependency(\.build) var build
    @Dependency(\.apiClient) var apiClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce(self.core)
    }


    func core(state: inout State, action: Action) -> Effect<Action> {

        switch action {

            case .onAppear:
                state.isAuthorized = userDefaults.boolForKey(UserDefaultKey.isAuthorized.rawValue)
                state.isUserFirstNameEmpty = userDefaults.boolForKey(UserDefaultKey.isUserFirstNameEmpty.rawValue)

                let isAuthorized = userDefaults.boolForKey(UserDefaultKey.isAuthorized.rawValue) == true
                let isAskPermissionCompleted = userDefaults.boolForKey(UserDefaultKey.isAskPermissionCompleted.rawValue) == true

                if isAuthorized {
                    if !isAskPermissionCompleted {

                        return .none
                    }
                }

                return .none

            case .binding(\.niceName):
                _ = state.niceName.capitalized

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
                let emailLoginInput = EmailLoginInput(name: state.niceName, email: state.email.lowercased())
                state.emailLoginInput = emailLoginInput

                return .run { send in
                    await send(.loginResponse(
                        await TaskResult {
                            try await apiClient.decodedResponse(
                                for: .authEngine(.authentication(.loginViaEmail(emailLoginInput))),
                                as: EmailLoginOutput.self
                            ).value
                        }
                    ))
                }

            case .binding(\.code):

                guard let emailLoginOutput = state.emailLoginOutput else {
                    return .none
                }

                if state.code.count == 6 {

                    state.isLoginRequestInFlight = true

                    let input = VerifyEmailInput(
                        niceName: state.niceName,
                        email: emailLoginOutput.email,
                        attemptId: emailLoginOutput.attemptId,
                        code: state.code
                    )

                    return .run { send in
                        await send(.verificationResponse(
                            await TaskResult {
                                try await apiClient.decodedResponse(
                                    for: .authEngine(.authentication(.verifyEmail(input))),
                                    as: SuccessfulLoginResponse.self,
                                    decoder: .iso8601
                                ).value
                            }
                        ))
                    }
                }

                return .none

            case .binding:
                return .none
                
            case let .loginResponse(.success(emailLoginOutput)):
                state.isLoginRequestInFlight = false
                state.isValidationCodeIsSend = true
                state.emailLoginOutput = emailLoginOutput

                return .none

            case .loginResponse(.failure(let error)):
                state.isLoginRequestInFlight = false
                state.isValidationCodeIsSend = false
                sharedLogger.logError(error.localizedDescription)
                return .none

            case let .verificationResponse(.success(loginRes)):

                if loginRes.user == nil || loginRes.access == nil {
                    return .none
                }

                state.isLoginRequestInFlight = false

                return .run { _ in

                    await withThrowingTaskGroup(of: Void.self) { group in

                        group.addTask {
                            await userDefaults.setBool(
                                true,
                                UserDefaultKey.isAuthorized.rawValue
                            )

                            await self.userDefaults.setBool(
                                loginRes.user?.fullName == nil ? false : true,
                                UserDefaultKey.isUserFirstNameEmpty.rawValue
                            )
                        }

                        group.addTask {
                            do {
                                try await keychainClient.saveCodable(loginRes.user, .user, build.identifier())
                                try await keychainClient.saveCodable(loginRes.access, .token, build.identifier())
                            } catch {
                                sharedLogger.logError(error.localizedDescription)
                            }
                        }
                    }
                }

            case .verificationResponse(.failure(_)):
                // state.alert = .init(title: TextState("Please try again!") )
                // send this for logs .init(title: TextState(error.description))
                state.isLoginRequestInFlight = false

                return .none


            case .destination(.presented(.termsAndPrivacy(.privacy))):
                state.destination = .termsAndPrivacy(.init(wbModel: .init(link: .terms)))
                return .none


            case .destination(.presented(.termsAndPrivacy(.terms))):
                state.destination = .termsAndPrivacy(.init(wbModel: .init(link: .privacy)))
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
