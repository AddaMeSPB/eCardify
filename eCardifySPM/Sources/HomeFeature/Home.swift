
import Foundation
import ComposableArchitecture

public struct Home: Reducer {
    public struct State: Equatable {
        public var wpass: WallatPassList.State?
    }

    public enum Action: Equatable {
    }

    public init() {}

    public var body: some Reducer<State, Action> {

        Reduce(self.core)
    }

    func core(state: inout State, action: Action) -> Effect<Action> {
        
    }
}
