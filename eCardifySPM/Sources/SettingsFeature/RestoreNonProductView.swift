
import ComposableArchitecture
import Foundation
import L10nResources
import SwiftUI

public struct RestoreNonProductView: View {
    @Bindable var store: StoreOf<StoreKitReducer>

    public init(store: StoreOf<StoreKitReducer>) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .center) {

            if store.isRestoring {
                ProgressView()
                Text(L("Processing..."))
            }

            Text(L("Restore!"))
                .font(.largeTitle)
                .fontWeight(.light)
                .padding()
        }
        .onAppear {
            store.send(.fetchProduct)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}

#if DEBUG
struct RestoreNonProductView_Previews: PreviewProvider {
    static var store = Store(
        initialState: StoreKitReducer.State()
    ) {
        StoreKitReducer()
    }
    static var previews: some View {
        RestoreNonProductView(store: store)
    }
}
#endif
