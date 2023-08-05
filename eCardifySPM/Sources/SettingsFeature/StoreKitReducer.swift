

import StoreKit
import Foundation
import AppConfiguration
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

        @PresentationState var alert: AlertState<Action.Alert>?
        public var products: [StoreKitClient.Product] = []
        public var type: ProductType = .basic

        public var isPurchasing: Bool
        public var isRestoring: Bool

        public struct ProductError: Error, Equatable {}

    }

    public enum Action: Equatable {
      case alert(PresentationAction<Alert>)
        case fetchProduct
        case paymentTransaction(StoreKitClient.PaymentTransactionObserverEvent)
        case productsResponse(TaskResult<StoreKitClient.ProductsResponse>)
        case restoreButtonTapped
        case tappedProduct(StoreKitClient.Product)
        case buySuccess

      public enum Alert: Equatable {
        case backToParent
      }
    }

    public init() {}

    @Dependency(\.dismiss) var dismiss
    @Dependency(\.storeKit) var storeKit
    @Dependency(\.appConfiguration) var appConfiguration

    public var body: some ReducerProtocol<State, Action> {

        Reduce(self.core)
    }

    func core(state: inout State, action: Action) -> EffectTask<Action> {
        switch action {
        case .fetchProduct:

            let productIds = appConfiguration.productIds.components(separatedBy: " ")
            let productIdsSET = Set(productIds)

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
                        try await self.storeKit.fetchProducts(productIdsSET)
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

          case .paymentTransaction(.removedTransactions):
            state.isPurchasing = false
            return .none

          case let .paymentTransaction(.restoreCompletedTransactionsFinished(transactions)):
            state.isRestoring = false
            state.alert = transactions.isEmpty ? .noRestoredPurchases : .restoredPurchases
            return .none

          case .paymentTransaction(.restoreCompletedTransactionsFailed):
            state.isRestoring = false
            state.alert = .restoredPurchasesFailed
            return .none

        case .buySuccess:
            return .none

        case .productsResponse(.success(let response)):
            state.products = response.products
            return .none

        case .productsResponse(.failure):
            // have to send message for analatices
            return .none

        case .restoreButtonTapped:
            state.isRestoring = true
            return .run { _ in
              await self.storeKit.restoreCompletedTransactions()
            }

        case .tappedProduct(let product):
            state.isPurchasing = true
            return .fireAndForget {
              let payment = SKMutablePayment()
              payment.productIdentifier = product.productIdentifier
              payment.quantity = 1
              await self.storeKit.addPayment(payment)
            }

          case .alert(.presented(.backToParent)):
            return .run { _ in
              await self.dismiss()
            }

          case .alert:
            return .none
        }
    }
}

// Alert
extension AlertState where Action == StoreKitReducer.Action.Alert {
  static let restoredPurchasesFailed: Self = .init {
    TextState("Error")
  } message: {
    TextState("We couldn’t restore purchases, please try again.")
  }

  static let restoredPurchases: Self = .init {
    TextState("Purchase restore.")
    
  } actions: {
    ButtonState(role: .destructive, action: .backToParent) {
      TextState("Back")
    }
  } message: {
    TextState("Your purchases was successfully restore.")
  }

  static let noRestoredPurchases: Self = .init {
    TextState("No Purchases")
  } message: {
    TextState("No purchases were found to restore.")
  }
}
