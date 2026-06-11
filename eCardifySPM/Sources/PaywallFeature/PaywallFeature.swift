import Foundation
import StoreKitClient
import AnalyticsClient
import AppConfiguration
import ComposableArchitecture

@Reducer
public struct PaywallFeature {

    static let maxRetryAttempts = 3

    @ObservableState
    public struct State: Equatable {
        public var products: [ECProduct] = []
        public var selectedProductID: String? = nil
        public var isPurchasing: Bool = false
        public var isRestoring: Bool = false
        public var isLoadingProducts: Bool = false
        public var loadError: String? = nil
        public var entitledProductIDs: Set<String> = []
        @Presents public var alert: AlertState<AlertAction>?

        public init() {}
    }

    @CasePathable
    public enum Action: Sendable {
        case onAppear
        case _productsLoaded([ECProduct])
        case _productsLoadFailed(String)
        case selectProduct(String)
        case retryLoadProducts
        case closeTapped
        case purchaseTapped
        case _purchaseResult(PurchaseResult)
        case restorePurchasesTapped
        case _restoreCompleted(Bool)
        case _entitlementChecked(EntitlementStatus)
        case alert(PresentationAction<AlertAction>)
        case delegate(Delegate)
    }

    @CasePathable
    public enum AlertAction: Equatable, Sendable {
        case ok
    }

    @CasePathable
    public enum Delegate: Equatable, Sendable {
        case purchased(productID: String)
        case dismissed
    }

    public init() {}

    @Dependency(\.storeKitClient) var storeKitClient
    @Dependency(\.analyticsClient) var analytics
    @Dependency(\.appConfiguration) var appConfiguration

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.isLoadingProducts else { return .none }
                state.isLoadingProducts = true
                state.loadError = nil
                let productIDs = Set(appConfiguration.productIds.components(separatedBy: " "))

                return .merge(
                    .run { send in
                        await analytics.track(.paywallViewed)
                    },
                    .run { send in
                        var lastError = ""
                        for attempt in 1...PaywallFeature.maxRetryAttempts {
                            do {
                                let products = try await storeKitClient.fetchProducts(productIDs)
                                if !products.isEmpty {
                                    await send(._productsLoaded(products))
                                    return
                                }
                                lastError = "StoreKit returned 0 products. This can happen in Sandbox — please try again."
                            } catch {
                                lastError = "StoreKit error: \(error.localizedDescription)"
                            }
                            if attempt < PaywallFeature.maxRetryAttempts {
                                try? await Task.sleep(for: .seconds(Double(attempt) * 2))
                            }
                        }
                        await send(._productsLoadFailed(lastError))
                    },
                    .run { send in
                        let status = await storeKitClient.checkEntitlements(productIDs)
                        await send(._entitlementChecked(status))
                    }
                )

            case ._productsLoaded(let products):
                state.isLoadingProducts = false
                state.products = products
                // Pre-select the most expensive product (FlexiCards)
                state.selectedProductID = products.last?.id
                return .none

            case ._productsLoadFailed(let error):
                state.isLoadingProducts = false
                state.loadError = error
                return .none

            case .selectProduct(let productID):
                state.selectedProductID = productID
                return .run { _ in
                    await analytics.track(.paywallProductSelected(productID: productID))
                }

            case .retryLoadProducts:
                state.isLoadingProducts = false
                return .send(.onAppear)

            case .closeTapped:
                return .merge(
                    .run { _ in await analytics.track(.paywallClosed) },
                    .send(.delegate(.dismissed))
                )

            case .purchaseTapped:
                guard let productID = state.selectedProductID else { return .none }
                state.isPurchasing = true
                return .run { send in
                    await analytics.track(.purchaseStarted(productID: productID))
                    do {
                        let result = try await storeKitClient.purchase(productID)
                        await send(._purchaseResult(result))
                    } catch {
                        await send(._purchaseResult(.failed(error.localizedDescription)))
                    }
                }

            case ._purchaseResult(let result):
                state.isPurchasing = false
                let productID = state.selectedProductID ?? ""
                switch result {
                case .success:
                    state.entitledProductIDs.insert(productID)
                    return .merge(
                        .run { _ in await analytics.track(.purchaseSucceeded(productID: productID)) },
                        .send(.delegate(.purchased(productID: productID)))
                    )
                case .cancelled:
                    return .run { _ in await analytics.track(.purchaseCancelled(productID: productID)) }
                case .pending:
                    state.alert = AlertState {
                        TextState("Purchase Pending")
                    } actions: {
                        ButtonState(action: .ok) { TextState("OK") }
                    } message: {
                        TextState("Your purchase is awaiting approval. You'll get access once it's confirmed.")
                    }
                    return .none
                case .failed(let error):
                    state.alert = AlertState {
                        TextState("Purchase Failed")
                    } actions: {
                        ButtonState(action: .ok) { TextState("OK") }
                    } message: {
                        TextState(error)
                    }
                    return .run { _ in await analytics.track(.purchaseFailed(productID: productID, error: error)) }
                }

            case .restorePurchasesTapped:
                state.isRestoring = true
                let productIDs = Set(appConfiguration.productIds.components(separatedBy: " "))
                return .run { send in
                    await analytics.track(.restorePurchasesTapped)
                    do {
                        try await storeKitClient.restorePurchases()
                        let status = await storeKitClient.checkEntitlements(productIDs)
                        if case .entitled = status {
                            await send(._restoreCompleted(true))
                        } else {
                            await send(._restoreCompleted(false))
                        }
                    } catch {
                        await send(._restoreCompleted(false))
                    }
                }

            case ._restoreCompleted(let found):
                state.isRestoring = false
                if found {
                    let productIDs = Set(appConfiguration.productIds.components(separatedBy: " "))
                    state.entitledProductIDs = productIDs
                    state.alert = AlertState {
                        TextState("Purchases Restored")
                    } actions: {
                        ButtonState(action: .ok) { TextState("OK") }
                    } message: {
                        TextState("Your purchases were successfully restored.")
                    }
                    return .run { _ in await analytics.track(.restorePurchasesSucceeded) }
                } else {
                    state.alert = AlertState {
                        TextState("No Purchases Found")
                    } actions: {
                        ButtonState(action: .ok) { TextState("OK") }
                    } message: {
                        TextState("No previous purchases were found to restore.")
                    }
                    return .run { _ in await analytics.track(.restorePurchasesFailed) }
                }

            case ._entitlementChecked(let status):
                if case .entitled(let ids) = status {
                    state.entitledProductIDs = ids
                }
                return .none

            case .alert:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
