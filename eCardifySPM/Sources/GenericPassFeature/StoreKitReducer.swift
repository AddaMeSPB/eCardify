
/// you can do that by select Reducer then click Command + Option + e
import Foundation
import ComposableArchitecture
import ComposableStoreKit
import StoreKit

public struct StoreKitReducer: ReducerProtocol {
    public struct State: Equatable {

        public enum ProductType: String, Codable, CaseIterable, Identifiable {
            public var id: Self {
                return self
            }

            case basic, custom
        }

        public init(
            basicCardProduct: Result<StoreKitClient.Product, StoreKitReducer.State.ProductError>? = nil,
            basicCardPurchasedAt: Date? = nil,
            customCardProduct: Result<StoreKitClient.Product, StoreKitReducer.State.ProductError>? = nil,
            customCardPurchasedAt: Date? = nil,
            isPurchasing: Bool = false,
            isRestoring: Bool = false
        ) {
            self.basicCardProductResponse = basicCardProduct
            self.basicCardPurchasedAt = basicCardPurchasedAt
            self.customCardProductResponse = customCardProduct
            self.customCardPurchasedAt = customCardPurchasedAt
            self.isPurchasing = isPurchasing
            self.isRestoring = isRestoring
        }

        public var basicCardProduct: StoreKitClient.Product? = nil
        public var customCardProduct: StoreKitClient.Product? = nil

        public var basicCardProductResponse: Result<StoreKitClient.Product, ProductError>?
        public var basicCardPurchasedAt: Date?

        public var customCardProductResponse: Result<StoreKitClient.Product, ProductError>?
        public var customCardPurchasedAt: Date?

        public var isPurchasing: Bool
        public var isRestoring: Bool

        public struct ProductError: Error, Equatable {}

        public var isBasicCardPurchased: Bool {
          return self.basicCardPurchasedAt != nil
        }

        public var isCustomCardPurchased: Bool {
          return self.customCardPurchasedAt != nil
        }

        public var isBasicProduct: ProductType {
            if basicCardProduct != nil {
                return ProductType.basic
            } else if customCardProduct != nil {
                return ProductType.custom
            } else {
                return ProductType.basic
            }
        }
    }

    public enum Action: Equatable {
        case fetchProduct
        case paymentTransaction(StoreKitClient.PaymentTransactionObserverEvent)
        case productsResponse(TaskResult<StoreKitClient.ProductsResponse>)
        case restoreButtonTapped
        case tappedProduct(StoreKitClient.Product)
        case basicCardProductResponse(StoreKitClient.Product)
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
                  let response = try await self.storeKit.fetchProducts(["BasicCard_eCardify_testing", "FlexiCards_eCardify_testing"])

                  guard
                    let product = response.products.first(where: { product in
                      product.productIdentifier == "BasicCard_eCardify_testing"
                    })
                  else { return }
                  await send(.basicCardProductResponse(product), animation: .default)
                }
              }
            }

        case .basicCardProductResponse(let product):
            state.basicCardProduct = product
            return .none

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
            return .none
        case .productsResponse(.failure(let error)):
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
