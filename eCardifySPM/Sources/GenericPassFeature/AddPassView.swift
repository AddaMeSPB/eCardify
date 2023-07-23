
import UIKit
import SwiftUI
import PassKit
import Foundation

public struct AddPassRepresentableView: UIViewControllerRepresentable {

    public typealias UIViewControllerType = PKAddPassesViewController

    @Environment(\.presentationMode) var presentationMode

    @Binding var pass: PKPass?

    public func makeUIViewController(context: Context) -> PKAddPassesViewController {
        let passVC = PKAddPassesViewController(pass: self.pass!)
        return passVC!
    }

    public func updateUIViewController(_ uiViewController: PKAddPassesViewController, context: Context) {
        // Nothing goes here
    }
}

import ComposableArchitecture

public struct AddPass: ReducerProtocol {
    public struct State: Equatable {
        var pass: PKPass?
    }

    public enum Action: Equatable {
        case pass(PKPass?)
    }

    public init() {}

    public var body: some ReducerProtocol<State, Action> {
        Reduce(self.core)
    }

    func core(state: inout State, action: Action) -> EffectTask<Action> {
        switch action {
        case .pass(_):
            return .none
        }
    }
}


public struct AddPassView: View {
    public let store: StoreOf<AddPass>

    public init(store: StoreOf<AddPass>) {
        self.store = store
    }

    public var body: some View {
        WithViewStore(self.store) { viewStore in
            AddPassRepresentableView(pass: viewStore.binding(get: \.pass, send: AddPass.Action.pass))
        }
    }
}

#if DEBUG
struct AddPassView_Previews: PreviewProvider {
    static var previews: some View {
        AddPassView(store: StoreOf<AddPass>(
            initialState: AddPass.State(),
            reducer: AddPass()
        ))
    }
}
#endif
