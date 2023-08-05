
import ComposableArchitecture
import Foundation
import SwiftUI

public struct RestoreNonProductView: View {
  let store: StoreOf<StoreKitReducer>

  public init(store: StoreOf<StoreKitReducer>) {
    self.store = store
  }

  public var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      VStack(alignment: .center) {

        if viewStore.isRestoring {
            ProgressView()
            Text("progessing...")
        }

        Text("Restore!")
          .font(.largeTitle)
          .fontWeight(.light)
          .padding()
      }
      .onAppear {
        viewStore.send(.fetchProduct)
      }
      .alert(store: self.store.scope(state: \.$alert, action: { .alert($0) }))
    }
  }
}

#if DEBUG
struct RestoreNonProductView_Previews: PreviewProvider {
  static var previews: some View {
    RestoreNonProductView(store: StoreOf<StoreKitReducer>(
      initialState: StoreKitReducer.State(),
      reducer: StoreKitReducer()
    ))
  }
}
#endif
