
import SwiftUI
import AppFeature
import KeychainClient
import SettingsFeature
import GenericPassFeature
import UserDefaultsClient
import AuthenticationView
import NotificationHelpers
import ComposableArchitecture

public struct AppView: View {

//    @Environment(\.scenePhase) private var scenePhase

    public let store: StoreOf<AppReducer>

    public init(store: StoreOf<AppReducer>) {
        self.store = store
    }

    public var body: some View {

        NavigationStackStore(
            self.store.scope(
                state: \.path,
                action: { .path($0) }
            )
        ) {
            WallatPassView(
                store: self.store.scope(state: \.walletState, action: { .walletAction($0) })
            )
            .onAppear {
                ViewStore(store.stateless).send(.onAppear)
            }
            .fullScreenCover(
                store: self.store.scope(state: \.$authState, action: { .auth($0) }),
                content: AuthenticationView.init(store:)
            )

        } destination: { state in

            switch state {
            case .genericForm:
                CaseLet(
                    state: /AppReducer.Path.State.genericForm,
                    action: AppReducer.Path.Action.genericForm,
                    then: GenericPassFormView.init(store:)
                )
            case .settings:
                CaseLet(
                    state: /AppReducer.Path.State.settings,
                    action: AppReducer.Path.Action.settings,
                    then: SettingsView.init(store:)
                )
            }
        }

    }
}

#if DEBUG
//struct AppView_Previews: PreviewProvider {
//    static var previews: some View {
//        AppView(store: StoreOf<AppReducer>(
//            initialState: AppReducer.State(walletState: .init( pContent: .generic())),
//            reducer: AppReducer()
//        ))
//    }
//}
#endif
