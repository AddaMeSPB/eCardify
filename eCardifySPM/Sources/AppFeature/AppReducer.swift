
import ComposableArchitecture
import SwiftUI
import UserDefaultsClient
import KeychainClient
import NotificationHelpers
import Build
import GenericPassFeature


public struct AppReducer: ReducerProtocol {
    public struct State: Equatable {

        public var walletState: WallatPassRouter.State

        public init(walletState: WallatPassRouter.State = .init()) {
            self.walletState = walletState
        }

    }

    public enum Action {
        case onAppear
        case appDelegate(AppDelegateReducer.Action)
        case didChangeScenePhase(ScenePhase)
        case walletAction(WallatPassRouter.Action)
    }

    @Dependency(\.userDefaults) var userDefaults
    @Dependency(\.userNotifications) var userNotifications
    @Dependency(\.remoteNotifications) var remoteNotifications
    @Dependency(\.mainRunLoop) var mainRunLoop
    @Dependency(\.keychainClient) var keychainClient
    @Dependency(\.build) var build

    public init() {}

    public var body: some ReducerProtocol<State, Action> {
//        Scope(state: \.tabState.settings.userSettings, action: /Action.appDelegate) {
//            AppDelegateReducer()
//        }

        Scope(state: \.walletState, action: /Action.walletAction) {
            WallatPassRouter()
        }

        Reduce { state, action in

            switch action {
            case .onAppear:
                return .none
            case let .appDelegate(.userNotifications(.didReceiveResponse(_, completionHandler))):
              return .fireAndForget { completionHandler() }
            case .appDelegate:
                return .none

            case .didChangeScenePhase(.active):
                return .none

            case .didChangeScenePhase(.background):
                return .none

            case .didChangeScenePhase:
                return .none

            case .walletAction:
                return .none
            }
        }
    }
}
