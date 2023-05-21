
import ComposableArchitecture
import SwiftUI
import UserDefaultsClient
import KeychainClient
import ECardifySharedModels
import NotificationHelpers
import AppFeature
import GenericPassFeature

public struct AppView: View {

    @Environment(\.scenePhase) private var scenePhase

    public let store: StoreOf<AppReducer>

    public init(store: StoreOf<AppReducer>) {
        self.store = store
    }

    public struct ViewState: Equatable {
        public init() {}
    }

    public var body: some View {

        WithViewStore(store, observe: { $0 }) { viewStore in
            WallatPassView(store:
                self.store.scope(
                    state: \.walletState,
                    action: AppReducer.Action.walletAction
                )
            )
        }
        .onAppear {
            ViewStore(store.stateless).send(.onAppear)
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
