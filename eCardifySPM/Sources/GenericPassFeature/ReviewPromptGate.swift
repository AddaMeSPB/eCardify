import Foundation
#if os(iOS)
import StoreKit
import UIKit
#endif

/// Gatekeeper for App Store review prompts.
///
/// Apple shows at most 3 review dialogs per user per 365 days, and
/// `requestReview` gives no callback when the dialog is suppressed — so a
/// single one-shot prompt can silently spend a user's only ask. Two moments
/// call into this gate:
/// - `requestNow()` — the first-card celebration (peak moment, always asks).
/// - `registerSessionAndRequestIfEligible()` — scene-active; a second chance
///   for engaged users iOS never actually showed the dialog to.
public enum ReviewPromptGate {
    static let sessionCountKey = "reviewPrompt.sessionCount"
    static let firstLaunchKey = "reviewPrompt.firstLaunchDate"
    static let lastRequestKey = "reviewPrompt.lastRequestDate"

    /// Foreground sessions before the fallback prompt is considered.
    static let minSessions = 5
    /// Seconds since first launch before the fallback prompt is considered.
    static let minAgeSinceFirstLaunch: TimeInterval = 7 * 24 * 3600
    /// Seconds between any two requestReview attempts.
    static let minIntervalBetweenRequests: TimeInterval = 60 * 24 * 3600

    @MainActor
    public static func requestNow() {
        #if os(iOS)
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) {
            // Stamp when we attempt the ask — Apple gives no callback if
            // the dialog is suppressed. A missed attempt (no foreground
            // scene yet) does not burn the cooldown.
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastRequestKey)
            AppStore.requestReview(in: scene)
        }
        #endif
    }

    /// Call on every scene-active transition. Counts the session and asks
    /// for a review once the user is demonstrably engaged: has a card,
    /// >= 5 sessions, >= 7 days since first launch, and >= 60 days since
    /// the last attempt.
    ///
    /// `hasCards` keeps the prompt away from users stuck on the
    /// login/empty state — they have nothing to rate yet, and a limited
    /// review ask spent there is wasted at best.
    @MainActor
    public static func registerSessionAndRequestIfEligible(hasCards: Bool) {
        let defaults = UserDefaults.standard
        let now = Date().timeIntervalSince1970

        if defaults.object(forKey: firstLaunchKey) == nil {
            defaults.set(now, forKey: firstLaunchKey)
        }
        let sessions = defaults.integer(forKey: sessionCountKey) + 1
        defaults.set(sessions, forKey: sessionCountKey)

        guard hasCards else { return }
        guard sessions >= minSessions else { return }
        guard now - defaults.double(forKey: firstLaunchKey) >= minAgeSinceFirstLaunch else { return }

        guard defaults.object(forKey: lastRequestKey) == nil
            || now - defaults.double(forKey: lastRequestKey) >= minIntervalBetweenRequests
        else { return }

        requestNow()
    }
}
