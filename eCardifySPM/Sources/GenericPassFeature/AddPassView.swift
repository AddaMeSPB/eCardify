
import UIKit
import SwiftUI
import PassKit
import LoggerKit
import Foundation
import L10nResources
import ComposableArchitecture

public struct AddPassRepresentableView: UIViewControllerRepresentable {

    public typealias UIViewControllerType = UIViewController

    @Environment(\.dismiss) var dismiss

    @Binding var pass: PKPass

    public func makeUIViewController(context: Context) -> UIViewController {
        guard let passVC = PKAddPassesViewController(pass: self.pass) else {
            // PKAddPassesViewController(pass:) returns nil when the pass can't
            // be presented (e.g. Wallet unavailable). Never crash — show a
            // dismissible fallback instead.
            sharedLogger.logError("PKAddPassesViewController(pass:) returned nil — cannot present Add to Wallet UI")
            return UIHostingController(
                rootView: AddPassUnavailableView {
                    dismiss()
                }
            )
        }
        return passVC
    }

    public func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Nothing goes here
    }
}

/// Shown inside the sheet when PKAddPassesViewController can't be created.
struct AddPassUnavailableView: View {
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(L("Unable to Add Pass"))
                .font(.headline)
            Text(L("This pass can't be added to Apple Wallet right now. Please contact support."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(L("Close"), action: onClose)
                .buttonStyle(.bordered)
                .padding(.top, 8)
        }
        .padding()
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
    @Bindable public var store: StoreOf<AddPass>

    public init(store: StoreOf<AddPass>) {
        self.store = store
    }

    public var body: some View {
        AddPassRepresentableView(pass: $store.pass)
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
