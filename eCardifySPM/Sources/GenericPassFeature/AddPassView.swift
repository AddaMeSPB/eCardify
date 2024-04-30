
import UIKit
import SwiftUI
import PassKit
import Foundation
import ComposableArchitecture

public struct AddPassRepresentableView: UIViewControllerRepresentable {

    public typealias UIViewControllerType = PKAddPassesViewController

    @Environment(\.presentationMode) var presentationMode

    @Binding var pass: PKPass

    public func makeUIViewController(context: Context) -> PKAddPassesViewController {
        guard let passVC = PKAddPassesViewController(pass: self.pass) else {
            fatalError("Failed to initialize PKAddPassesViewController with the provided pass")
        }
        return passVC
    }

    public func updateUIViewController(_ uiViewController: PKAddPassesViewController, context: Context) {
        // Nothing goes here
    }
}


@Reducer
public struct AddPass {

    @ObservableState
    public struct State: Equatable {
        var pass: PKPass
    }


    @CasePathable
    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case pass(PKPass)
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce(self.core)
    }

    func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .pass(_):
            return .none
        case .binding(_):
            return .none
        }
    }
}


public struct AddPassView: View {
    @Perception.Bindable public var store: StoreOf<AddPass>

    public init(store: StoreOf<AddPass>) {
        self.store = store
    }

    public var body: some View {
        WithPerceptionTracking {
            AddPassRepresentableView(pass: $store.pass)
        }
    }
}

#if DEBUG
struct AddPassView_Previews: PreviewProvider {
    static var previews: some View {
        AddPassView(store: .init(initialState: AddPass.State(pass: .init())) {
                AddPass()
            }
        )
    }
}
#endif
