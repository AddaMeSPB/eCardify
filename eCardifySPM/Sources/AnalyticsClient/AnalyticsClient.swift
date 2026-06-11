import SwiftUI
import Dependencies
import DependenciesMacros

// MARK: - Analytics Events

public enum AnalyticsEvent: Sendable {
    // App lifecycle
    case appLaunched
    case appForegrounded

    // Paywall
    case paywallViewed
    case paywallClosed
    case paywallProductSelected(productID: String)
    case purchaseStarted(productID: String)
    case purchaseSucceeded(productID: String)
    case purchaseFailed(productID: String, error: String)
    case purchaseCancelled(productID: String)
    case restorePurchasesTapped
    case restorePurchasesSucceeded
    case restorePurchasesFailed

    // Card creation
    case cardCreationStarted
    case cardCreated
    case cardDeleted

    // Settings
    case settingsOpened
    case loggedOut
    case accountDeleted

    // Screen tracking
    case screenViewed(name: String)

    var nameAndProperties: (String, [String: String]) {
        switch self {
        case .appLaunched:
            return ("app_launched", [:])
        case .appForegrounded:
            return ("app_foregrounded", [:])
        case .paywallViewed:
            return ("paywall_viewed", [:])
        case .paywallClosed:
            return ("paywall_closed", [:])
        case .paywallProductSelected(let productID):
            return ("paywall_product_selected", ["product_id": productID])
        case .purchaseStarted(let productID):
            return ("purchase_started", ["product_id": productID])
        case .purchaseSucceeded(let productID):
            return ("purchase_succeeded", ["product_id": productID])
        case .purchaseFailed(let productID, let error):
            return ("purchase_failed", ["product_id": productID, "error": error])
        case .purchaseCancelled(let productID):
            return ("purchase_cancelled", ["product_id": productID])
        case .restorePurchasesTapped:
            return ("restore_purchases_tapped", [:])
        case .restorePurchasesSucceeded:
            return ("restore_purchases_succeeded", [:])
        case .restorePurchasesFailed:
            return ("restore_purchases_failed", [:])
        case .cardCreationStarted:
            return ("card_creation_started", [:])
        case .cardCreated:
            return ("card_created", [:])
        case .cardDeleted:
            return ("card_deleted", [:])
        case .settingsOpened:
            return ("settings_opened", [:])
        case .loggedOut:
            return ("logged_out", [:])
        case .accountDeleted:
            return ("account_deleted", [:])
        case .screenViewed(let name):
            return ("screen_viewed", ["screen_name": name])
        }
    }
}

// MARK: - Client

@DependencyClient
public struct AnalyticsClient: Sendable {
    public var track: @Sendable (AnalyticsEvent) async -> Void
    public var identify: @Sendable (String) async -> Void
}

// MARK: - Dependency Registration

extension AnalyticsClient: DependencyKey {
    public static let testValue = AnalyticsClient()
    public static let previewValue = AnalyticsClient(
        track: { _ in },
        identify: { _ in }
    )
}

extension DependencyValues {
    public var analyticsClient: AnalyticsClient {
        get { self[AnalyticsClient.self] }
        set { self[AnalyticsClient.self] = newValue }
    }
}

// MARK: - Screen Tracking View Modifier

public struct ScreenTrackingModifier: ViewModifier {
    let screenName: String
    @Dependency(\.analyticsClient) var analytics

    public func body(content: Content) -> some View {
        content
            .onAppear {
                Task {
                    await analytics.track(.screenViewed(name: screenName))
                }
            }
    }
}

public extension View {
    func trackScreen(_ name: String) -> some View {
        modifier(ScreenTrackingModifier(screenName: name))
    }
}
