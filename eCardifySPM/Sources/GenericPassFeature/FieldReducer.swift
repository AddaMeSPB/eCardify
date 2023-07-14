import SwiftUI
import ECardifySharedModels
import ComposableArchitecture

public struct FieldReducer: ReducerProtocol {
    public struct State: Equatable, Identifiable {
        public var id: UUID
        @BindingState public var field: Field
        public var fieldType: FieldTypes
    }

    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
    }

    public init() {}

    public var body: some ReducerProtocol<State, Action> {
        BindingReducer()
        Reduce(self.core)
    }

    func core(state: inout State, action: Action) -> EffectTask<Action> {
        switch action {
        case .binding(\.$field.value):
            if state.field.key == "email" {
                state.field.value = state.field.value.lowercased()
            }

            return .none
        case .binding:
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
                        Text("NAME")
                            .font(.title3)
                            .fontWeight(.medium)

                        TextField(
                            "Your nice name",
                            text: viewStore.binding(\.$field.value),
                            axis: .vertical
                        )
                        .font(.title2)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .autocorrectionDisabled()
                    }

                case .secondary:

                    VStack(alignment: .leading) {
                        Text(viewStore.field.key.uppercased())
                            .font(.title3)
                            .fontWeight(.medium)
                        TextField(
                            "\(viewStore.field.key.capitalized) goes here",
                            text: viewStore.binding(\.$field.value),
                            axis: .vertical
                        )
                        .font(.title3)
                        .fontWeight(.medium)
                        .lineLimit(2)
                    }


                case .auxiliary:
                    VStack(alignment: .leading) {
                        Text(viewStore.field.key.uppercased())
                            .font(.title3)
                            .fontWeight(.medium)

                        TextField(
                            "\(viewStore.field.key.capitalized) goes here",
                            text: viewStore.binding(\.$field.value),
                            axis: .vertical
                        )
                        .font(.title3)
                        .fontWeight(.medium)
                    }


                case .back:
                    EmptyView()
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 3)
        }
    }
}

#if DEBUG
struct FieldView_Previews: PreviewProvider {
    static var state = FieldReducer.State(
        id: UUID(),
        field: .init(key: "mobile", value: "+38268820003, \n+38220230446, \n+38269999993"),
        fieldType: .auxiliary
    )
    static var previews: some View {
        FieldView(store:
            .init(
                initialState: state,
                reducer: FieldReducer()
            )
        )
        .foregroundColor(Color(red: 0.82, green: 0.94, blue: 1.00))
        .background(Color(hex: "#2C71DA"))

    }
}
#endif

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0

        scanner.scanHexInt64(&rgbValue)

        self.init(
            red: Double((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: Double((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgbValue & 0x0000FF) / 255.0
        )
    }
}
