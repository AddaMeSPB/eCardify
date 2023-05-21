import SwiftUI
import ECardifySharedModels
import ComposableArchitecture

public struct PassContentsReducer: ReducerProtocol {

    public enum State: Equatable {
        case coupon(PassContentReducer.State)
        case boardingPass(PassContentReducer.State)
        case storeCard(PassContentReducer.State)
        case eventTicket(PassContentReducer.State)
        case generic(PassContentReducer.State)

        public init() {
            self = .generic(.init(passContent: .init(primaryFields: [.init()])))
        }
    }

    public enum Action: Equatable {
        case coupon(PassContentReducer.Action)
        case boardingPass(PassContentReducer.Action)
        case storeCard(PassContentReducer.Action)
        case eventTicket(PassContentReducer.Action)
        case generic(PassContentReducer.Action)
    }

    public init() {}

    public var body: some ReducerProtocol<State, Action> {

        Reduce(self.core)
            .ifCaseLet(/State.generic, action: /Action.generic) {
                PassContentReducer()
            }
    }

    func core(state: inout State, action: Action) -> EffectTask<Action> {
        switch action {
        case  .coupon:
            state = .coupon(.init(passContent: .init(primaryFields: [.init()])))
            return .none
        case .boardingPass:
            state = .boardingPass(.init(passContent: .init(primaryFields: [.init()])))
            return .none
        case .storeCard:
            state = .storeCard(.init(passContent: .init(primaryFields: [.init()])))
            return .none
        case .eventTicket:
            state = .eventTicket(.init(passContent: .init(primaryFields: [.init()])))
            return .none
        case .generic:
            return .none
        }
    }
}

public struct PassContentsView: View {
  let store: StoreOf<PassContentsReducer>

  public init(store: StoreOf<PassContentsReducer>) {
    self.store = store
  }

  public var body: some View {
    SwitchStore(self.store) { state in
      switch state {
      case .coupon:
        CaseLet(/PassContentsReducer.State.coupon, action: PassContentsReducer.Action.coupon) { store in
            PassContentView(store: store)
        }

      case .generic:
        CaseLet(/PassContentsReducer.State.generic, action: PassContentsReducer.Action.generic) { store in
            PassContentView(store: store)
        }

      default:
          EmptyView()
      }
    }
    .navigationViewStyle(.stack)
  }
}
