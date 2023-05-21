import SwiftUI
import ECardifySharedModels
import ComposableArchitecture

public struct PassContentReducer: ReducerProtocol {
    public struct State: Equatable {
        public init(
            passContent: PassContent,
            fields: IdentifiedArrayOf<FieldReducer.State> = []
        ) {
            self.passContent = passContent
            self.fields = fields
        }

        public var passContent: PassContent
        public var fields: IdentifiedArrayOf<FieldReducer.State> = []
    }

    public enum Action: Equatable {
        case onAppear
        case passContent(PassContent)
        case passContentTransit(PassContentTransit)
        case field(id: FieldReducer.State.ID, action: FieldReducer.Action)
    }

    public init() {}

    public var body: some ReducerProtocol<State, Action> {

        Reduce(self.core)
            .forEach(\.fields, action: /Action.field(id:action:)) {
                FieldReducer()
            }
    }

    func core(state: inout State, action: Action) -> EffectTask<Action> {
        switch action {
        case .onAppear:
            return .none

        case .field(id: _, action: _):
            return .none

        case .passContent:
            return .none

        case .passContentTransit:
            return .none
        }
    }
}

public struct PassContentView: View {

    let store: StoreOf<PassContentReducer>

    public init(store: StoreOf<PassContentReducer>) {
      self.store = store
    }

    public var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            VStack {
                ForEachStore(
                    self.store.scope(
                        state: \.fields,
                        action: PassContentReducer.Action.field(id:action:)
                    )
                ) { rawStore in
                    FieldView(store: rawStore)
                }
            }
            .onAppear {
                viewStore.send(.onAppear)
            }
        }
    }
}


