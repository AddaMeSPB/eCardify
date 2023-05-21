import SwiftUI
import ECardifySharedModels
import ComposableArchitecture

public struct FieldReducer: ReducerProtocol {
    public struct State: Equatable, Identifiable {
        public var id: UUID
        public var field: Field
        public var fieldType: FieldTypes
    }

    public enum Action: Equatable {
        case changeText(String)
    }

    public init() {}

    public var body: some ReducerProtocol<State, Action> {
        Reduce(self.core)
    }

    func core(state: inout State, action: Action) -> EffectTask<Action> {
        switch action {
        case .changeText(let string):
            state.field.value = string
            return .none
        }
    }

}


public struct FieldView: View {
    let store: StoreOf<FieldReducer>

    public init(store: StoreOf<FieldReducer>) {
        self.store = store
    }

    public var body: some View {
        WithViewStore(self.store, observe: {$0}) { viewStore in
            VStack {

                switch viewStore.fieldType {
                case .header:
                    EmptyView()
                    
                case .primary:
                    VStack(alignment: .leading) {
                        Text("Primary field")
                            .font(.title3)
                            .fontWeight(.medium)
                            .padding(.horizontal)
                            .padding(.bottom, 5)

                        Text("NAME")
                            .font(.title3)
                            .fontWeight(.medium)
                            .padding(.horizontal)

                        TextField(
                            "Your nice name",
                            text: viewStore.binding(get: \.field.value, send: FieldReducer.Action.changeText)
                        )
                        .font(.title)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .padding(.horizontal)
                        .padding(.bottom, 5)
                    }

                case .secondary:
                    EmptyView()

                case .auxiliary:
                    EmptyView()

                case .back:
                    EmptyView()
                }
            }
        }
    }
}

#if DEBUG
struct FieldView_Previews: PreviewProvider {
    static var state = FieldReducer.State(
        id: UUID(),
        field: .init(),
        fieldType: .primary
    )
    static var previews: some View {
        FieldView(store:
            .init(
                initialState: state,
                reducer: FieldReducer()
            )
        )
    }
}
#endif
