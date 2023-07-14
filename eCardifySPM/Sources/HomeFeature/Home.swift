
import Foundation
import ComposableArchitecture

public struct Home: ReducerProtocol {
    public struct State: Equatable {
        public var wpass: WallatPassList.State?
    }

    public enum Action: Equatable {
    }

    public init() {}

    public var body: some ReducerProtocol<State, Action> {

        Reduce(self.core)
    }

    func core(state: inout State, action: Action) -> EffectTask<Action> {
        
    }
}
