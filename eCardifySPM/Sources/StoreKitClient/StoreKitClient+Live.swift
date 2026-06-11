import Dependencies
import StoreKit

extension StoreKitClient {
    public static let liveValue = StoreKitClient(
        fetchProducts: { productIDs in
            let products = try await Product.products(for: productIDs)
            return products.map { product in
                ECProduct(
                    id: product.id,
                    displayName: product.displayName,
                    displayPrice: product.displayPrice,
                    price: product.price,
                    isNonConsumable: product.type == .nonConsumable
                )
            }
            .sorted { $0.price < $1.price }
        },

        purchase: { productID in
            let products = try await Product.products(for: [productID])
            guard let product = products.first else {
                return .failed("Product not found")
            }

            let result = try await product.purchase()

            switch result {
            case let .success(verification):
                switch verification {
                case let .verified(transaction):
                    await transaction.finish()
                    return .success
                case .unverified:
                    return .failed("Transaction verification failed")
                }
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed("Unknown purchase result")
            }
        },

        restorePurchases: {
            try await AppStore.sync()
        },

        checkEntitlements: { productIDs in
            var entitled: Set<String> = []
            for await result in Transaction.currentEntitlements {
                if case let .verified(transaction) = result {
                    if productIDs.contains(transaction.productID),
                       transaction.revocationDate == nil
                    {
                        entitled.insert(transaction.productID)
                    }
                }
            }
            return entitled.isEmpty ? .none : .entitled(productIDs: entitled)
        },

        transactionUpdates: {
            AsyncStream { continuation in
                let task = Task {
                    for await result in Transaction.updates {
                        if case let .verified(transaction) = result {
                            await transaction.finish()
                            // Re-check all entitlements on any transaction update
                            continuation.yield(.entitled(productIDs: [transaction.productID]))
                        }
                    }
                    continuation.finish()
                }
                continuation.onTermination = { _ in
                    task.cancel()
                }
            }
        }
    )
}
