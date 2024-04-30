
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

    @Perception.Bindable  public var store: StoreOf<AppReducer>

    public init(store: StoreOf<AppReducer>) {
        self.store = store
    }

    public var body: some View {

        WithPerceptionTracking {
            NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
                WalletPassView(
                    store: self.store.scope(state: \.walletState, action: \.walletAction )
                )
                .onAppear {
                    store.send(.onAppear)
                }
                .fullScreenCover(
                    store: self.store.scope(state: \.$authState, action: \.auth ),
                    content: AuthenticationView.init(store:)
                )
                
            } destination: { store in
                
                switch store.case {
                    case let .genericForm(gstore):
                        GenericPassFormView.init(store: gstore)
                    case let .settings(sstore):
                        SettingsView.init(store: sstore)
                }
                
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
