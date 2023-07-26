
import Build
import SwiftUI
import KeychainClient
import SettingsFeature
import UserDefaultsClient
import GenericPassFeature
import AuthenticationCore
import NotificationHelpers
import ECSharedModels
import ComposableArchitecture

public struct AppReducer: ReducerProtocol {
    public struct State: Equatable {
        public init(
            path: StackState<AppReducer.Path.State> = StackState<Path.State>(),
            walletState: WallatPassList.State = WallatPassList.State(),
            authState: Login.State? = nil
        ) {
            self.path = path
            self.walletState = walletState
            self.authState = authState
        }

        public var path = StackState<Path.State>()
        public var walletState = WallatPassList.State()
        @PresentationState public var authState: Login.State? = nil
        public var isSheetLoginPresented: Bool { authState != nil }
    }

    public enum Action {
        case path(StackAction<Path.State, Path.Action>)
        case onAppear
        case appDelegate(AppDelegateReducer.Action)
        case didChangeScenePhase(ScenePhase)
        case walletAction(WallatPassList.Action)
        case auth(PresentationAction<Login.Action>)
        case isSheetLogin(isPresented: Bool)
    }


    @Dependency(\.userDefaults) var userDefaults
    @Dependency(\.userNotifications) var userNotifications
    @Dependency(\.remoteNotifications) var remoteNotifications
    @Dependency(\.mainRunLoop) var mainRunLoop
    @Dependency(\.keychainClient) var keychainClient
    @Dependency(\.build) var build

    public init() {}


    public var body: some ReducerProtocolOf<Self> {

        // Scope(state: \.tabState.settings.userSettings, action: /Action.appDelegate) {
        //  AppDelegateReducer()
        // }

        Scope(state: \.walletState, action: /Action.walletAction) {
            WallatPassList()
        }

        Reduce(self.core)
            .forEach(\.path, action: /Action.path) {
                Path()
            }
            .ifLet(\.$authState, action: /AppReducer.Action.auth) {
                Login()
            }
    }

    func core(state: inout State, action: Action) -> EffectTask<Action> {
        switch action {
        case .onAppear:
//            state.authState = .init()
            return .none

        case .appDelegate:
            return .none

        case .didChangeScenePhase(.active):
            return .none

        case .didChangeScenePhase(.background):
            return .none

        case .didChangeScenePhase:
            return .none

        case .walletAction(.destination(.presented(.add(.openSheetLogin(let bool))))):
            return .run { send in
                await send(.isSheetLogin(isPresented: bool))
            }

        case .walletAction:
            return .none

        case .auth(.presented(.verificationResponse(.success))):
            state.walletState.isAuthorized = true

            return .run { send in
                await send(.walletAction(.destination(.presented(.add(.update(isAuthorized: true))))))
                await send(.isSheetLogin(isPresented: false))
            }

        case .auth:
            return .none

        case .isSheetLogin(isPresented: let isPresented):
            state.authState = isPresented ? .init() : nil

            return .none

        case .path:
            return .none
        }
    }

    public struct Path: ReducerProtocol {

        public enum State: Equatable {
            case genericForm(GenericPassForm.State)
            case settings(Settings.State)
        }

        public enum Action: Equatable {
            case genericForm(GenericPassForm.Action)
            case settings(Settings.Action)
        }

        public init() {}

        public var body: some ReducerProtocolOf<Self> {
            Scope(state: /State.genericForm, action: /Action.genericForm) {
                GenericPassForm()
            }

            Scope(state: /State.settings, action: /Action.settings) {
                Settings()
            }
        }
    }
}
