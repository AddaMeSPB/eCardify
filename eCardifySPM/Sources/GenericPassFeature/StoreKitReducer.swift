

import StoreKit
import Foundation
import ComposableStoreKit
import ComposableArchitecture

public struct StoreKitReducer: ReducerProtocol {
    public struct State: Equatable {

        public enum ProductType: String, Codable, CaseIterable, Identifiable {
            public var id: Self {
                return self
            }

            case basic, custom
        }

        public init(
            products: [StoreKitClient.Product] = [],
            isPurchasing: Bool = false,
            isRestoring: Bool = false
        ) {
            self.products = products
            self.isPurchasing = isPurchasing
            self.isRestoring = isRestoring
        }

        public var product: StoreKitClient.Product? {
            switch type {
            case .basic:
                return products.first
            case .custom:
                return products.last
            }
        }
        
        public var products: [StoreKitClient.Product] = []
        public var type: ProductType = .basic

        public var isPurchasing: Bool
        public var isRestoring: Bool

        public struct ProductError: Error, Equatable {}

    }

    public enum Action: Equatable {
        case fetchProduct
        case paymentTransaction(StoreKitClient.PaymentTransactionObserverEvent)
        case productsResponse(TaskResult<StoreKitClient.ProductsResponse>)
        case restoreButtonTapped
        case tappedProduct(StoreKitClient.Product)
        case buySuccess
    }

    public init() {}

    @Dependency(\.storeKit) var storeKit

    public var body: some ReducerProtocol<State, Action> {

        Reduce(self.core)
    }

    func core(state: inout State, action: Action) -> EffectTask<Action> {
        switch action {
        case .fetchProduct:

            return .run {  send in
              await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                  for await event in self.storeKit.observer() {
                    await send(.paymentTransaction(event), animation: .default)
                  }
                }

                group.addTask {
                  await send(.productsResponse(
                    TaskResult {
                        try await self.storeKit.fetchProducts(["BasicCard_eCardify_testing", "FlexiCards_eCardify_testing"])
                    }
                  ), animation: .default)
                }
              }
            }

        case .paymentTransaction(.updatedTransactions(let pt)):
            guard let transactionState = pt.first?.transactionState
            else {
                return .none
            }

            if transactionState == .purchased {
                return .run { send in
                    await send(.buySuccess)
                }
            }

            return .none

        case .buySuccess:
            return .none

        case .paymentTransaction:
            return .none

            
        case .productsResponse(.success(let response)):
            state.products = response.products
            return .none
        case .productsResponse(.failure):
            // have to send message for analatices
            return .none

        case .restoreButtonTapped:
            return .none

        case .tappedProduct(let product):
            state.isPurchasing = true
            return .fireAndForget {
              let payment = SKMutablePayment()
              payment.productIdentifier = product.productIdentifier
              payment.quantity = 1
              await self.storeKit.addPayment(payment)
            }
        }
    }
}
