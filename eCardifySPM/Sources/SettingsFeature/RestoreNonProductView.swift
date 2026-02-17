
import ComposableArchitecture
import Foundation
import SwiftUI

public struct RestoreNonProductView: View {
    @Perception.Bindable var store: StoreOf<StoreKitReducer>

    public init(store: StoreOf<StoreKitReducer>) {
        self.store = store
    }

    public var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .center) {

                if store.isRestoring {
                    ProgressView()
                    Text("Processing...")
                }

                Text("Restore!")
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
