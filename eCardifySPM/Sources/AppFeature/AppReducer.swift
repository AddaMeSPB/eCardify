
import Build
import SwiftUI
import KeychainClient
import SettingsFeature
import GenericPassFeature
import AuthenticationCore
import NotificationHelpers
import ECSharedModels
import ComposableArchitecture

@Reducer
public struct AppReducer {

    @Reducer(state: .equatable)
    public enum Path {
        case genericForm(GenericPassForm)
        case settings(Settings)
    }

    @ObservableState
    public struct State: Equatable {
        public init(
            path: StackState<Path.State> = StackState<Path.State>(),
            walletState: WalletPassList.State = WalletPassList.State(),
            authState: Login.State? = nil
        ) {
            self.path = path
            self.walletState = walletState
            self.authState = authState
        }

        public var path = StackState<Path.State>()
        public var walletState: WalletPassList.State
        @Presents public var authState: Login.State? = nil
        public var isSheetLoginPresented: Bool { authState != nil }
    }

    public enum Action {
        case path(StackActionOf<Path>)
        case onAppear
        case appDelegate(AppDelegateReducer.Action)
        case didChangeScenePhase(ScenePhase)
        case walletAction(WalletPassList.Action)
        case auth(PresentationAction<Login.Action>)
        case isSheetLogin(isPresented: Bool)
    }

    @Dependency(\.userNotifications) var userNotifications
    @Dependency(\.remoteNotifications) var remoteNotifications
    @Dependency(\.mainRunLoop) var mainRunLoop
    @Dependency(\.keychainClient) var keychainClient
    @Dependency(\.build) var build
    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some ReducerOf<Self> {

//      Scope(state: \.walletState.$destination.wrappedValue, action: /Action.appDelegate) {
//          AppDelegateReducer()
//      }

        Scope(state: \.walletState, action: /Action.walletAction) {
            WalletPassList()
        }

        Reduce(self.core)
            .forEach(\.path, action: \.path) 
            .ifLet(\.$authState, action: /AppReducer.Action.auth) {
                Login()
            }
    }

    func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-UI_TESTING") {
                state.walletState.$isAuthorized.withLock { $0 = true }
            }
            #endif
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


        case .walletAction(.openSheetLogin(let bool)):
            return .run { send in
                await send(.isSheetLogin(isPresented: bool))
            }

        case .walletAction:
            return .none

        case .auth(.presented(.verificationResponse(.success))):
            // isAuthorized is @Shared — automatically synced via AppStorage.
            // The .update(isAuthorized:) action below is redundant for the value itself
            // but signals GenericPassForm that auth completed (e.g., to proceed with pass creation).
            return .run { send in
                try await clock.sleep(for: .seconds(1))
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

}
