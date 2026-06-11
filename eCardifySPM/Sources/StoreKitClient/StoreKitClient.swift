import Dependencies
import DependenciesMacros
import StoreKit

// MARK: - Value Types

public struct ECProduct: Equatable, Sendable, Identifiable {
    public let id: String
    public let displayName: String
    public let displayPrice: String
    public let price: Decimal
    public let isNonConsumable: Bool

    public init(
        id: String,
        displayName: String,
        displayPrice: String,
        price: Decimal,
        isNonConsumable: Bool
    ) {
        self.id = id
        self.displayName = displayName
        self.displayPrice = displayPrice
        self.price = price
        self.isNonConsumable = isNonConsumable
    }
}

public enum PurchaseResult: Equatable, Sendable {
    case success
    case cancelled
    case pending
    case failed(String)
}

public enum EntitlementStatus: Equatable, Sendable {
    case none
    case entitled(productIDs: Set<String>)
}

// MARK: - Client

@DependencyClient
public struct StoreKitClient: Sendable {
    public var fetchProducts: @Sendable (_ productIDs: Set<String>) async throws -> [ECProduct]
    public var purchase: @Sendable (_ productID: String) async throws -> PurchaseResult
    public var restorePurchases: @Sendable () async throws -> Void
    public var checkEntitlements: @Sendable (_ productIDs: Set<String>) async -> EntitlementStatus = { _ in .none }
    public var transactionUpdates: @Sendable () -> AsyncStream<EntitlementStatus> = { AsyncStream { $0.finish() } }
}

// MARK: - Dependency Registration

extension StoreKitClient: DependencyKey {
    public static let testValue = StoreKitClient()
    public static let previewValue = StoreKitClient(
        fetchProducts: { _ in [] },
        purchase: { _ in .cancelled },
        restorePurchases: {},
        checkEntitlements: { _ in .none },
        transactionUpdates: { AsyncStream { $0.finish() } }
    )
}

extension DependencyValues {
    public var storeKitClient: StoreKitClient {
        get { self[StoreKitClient.self] }
        set { self[StoreKitClient.self] = newValue }
    }
}
