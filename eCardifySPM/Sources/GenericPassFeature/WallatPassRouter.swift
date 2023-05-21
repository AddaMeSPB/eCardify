import SwiftUI
import Foundation
import ComposableArchitecture
import ECardifySharedModels

import Foundation

public extension Bundle {
    @Sendable func decode<T: Decodable>(_ type: T.Type,
                              from file: String,
                              dateDecodingStategy: JSONDecoder.DateDecodingStrategy = .deferredToDate,
                              keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys
    ) throws -> T {
        guard let url = self.url(forResource: file, withExtension: nil) else {
            fatalError("Error: Failed to locate \(file) in bundle.")
        }

        guard let data = try? Data(contentsOf: url) else {
            fatalError("Error: Failed to load \(file) from bundle.")
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = keyDecodingStrategy

        do {
            let loaded = try decoder.decode(T.self, from: data)
            return loaded
        } catch {
            fatalError("Error: Failed to decode \(file) from bundle. \(error)")
        }

    }
}


extension Pass {
    static func general() -> Pass {
        return try! Bundle.main.decode(Pass.self, from: "Pass.json")
    }
}

public struct WallatPassRouter: ReducerProtocol {
    public struct State: Equatable {
        public init(
            pass: Pass = .mock,
            passContents: PassContentsReducer.State = .init()
        ) {
            self.pass = pass
            self.passContents = passContents
        }

        @BindingState public var pass: Pass = .mock
        public var passContents: PassContentsReducer.State
    }

    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case passContentsAction(PassContentsReducer.Action)
    }

    public init() {}

    public var body: some ReducerProtocol<State, Action> {

        Scope(state: \.passContents, action: /Action.passContentsAction) {
            PassContentsReducer()
        }

        BindingReducer()
        Reduce(self.core)
    }

    func core(state: inout State, action: Action) -> EffectTask<Action> {
        switch action {
        case let .passContentsAction(aaction):
            switch aaction {

            case .coupon(_):
                return .none
            case .boardingPass(_):
                return .none
            case .storeCard(_):
                return .none
            case .eventTicket(_):
                return .none
            case let .generic(gaction):
                state.passContents(.generic.primaryFields.first?.value)
                switch gaction {
                case .onAppear:

                    return .none
                case .passContent(_):
                    return .none
                case .passContentTransit(_):
                    return .none
                case .field(id: let id, action: let action):


                    return .none
                }
            }

        case .binding:
            return .none
        }
    }
}
