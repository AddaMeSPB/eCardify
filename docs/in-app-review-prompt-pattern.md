# In-App Review Prompt Pattern

Reusable playbook for triggering `SKStoreReviewController` in any iOS app.
Origin: eCardify refactor 2026-04-23 (free-tier users never hit "card #2"
trigger, so prompt never fired for the exact users we most need reviews from).

## The rule

**Prompt after the first meaningful success, not before.** If your app has a
free tier that most users never leave, the prompt must fire inside the free
tier — not at the paywall, not on a milestone only paying users reach.

## Where to put it

Trigger location = the reducer/effect that runs when the user successfully
completes the core action of your app:

| App | Success moment |
|---|---|
| eCardify | 1st card saved |
| SubTracker | 1st subscription added |
| FixLog | 1st warranty / appliance logged |
| VoicePrice | 1st invoice generated |
| Photo Cleanup | 1st duplicate batch deleted |
| RePhoto | 1st photo edit completed + saved |

Pick the action that makes the user say "this app works." That's the moment.

## Canonical snippet (SwiftUI + TCA)

```swift
// In the reducer effect that fires after a successful save:

// 1. Show the success UI FIRST so the user sees their win.
await send(.showSuccessView(result))

// 2. Small delay so the success screen settles before the system alert
//    appears on top of it (prevents jarring overlap).
#if os(iOS)
if shouldPromptForReview(successCount: /* from local DB */) {
    try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s
    await MainActor.run {
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) {
            SKStoreReviewController.requestReview(in: scene)
        }
    }
}
#endif

/// Return `true` on the 1st successful completion. Apple's
/// SKStoreReviewController enforces a hard limit of 3 prompts per user
/// per 365 days system-wide, so we do NOT need extra local throttling.
func shouldPromptForReview(successCount: Int) -> Bool {
    successCount >= 1
}
```

## Don't

- **Don't prompt on first launch.** The user hasn't done anything yet — you'll
  get 1-star "what is this" reviews.
- **Don't prompt on error or failure.** Frustrated user → bad review.
- **Don't prompt at the paywall.** Mixes "pay me" with "rate me" — feels manipulative.
- **Don't add your own "Are you enjoying X?" popup before the system prompt.**
  Apple explicitly forbids this in App Store Review Guideline 1.1.7. The
  system prompt is the only allowed prompt.
- **Don't call `requestReview` more than once per success event.** Apple
  caches and ignores repeats, but it clutters your code.
- **Don't couple the prompt to a specific count like `== 2`.** If your free
  tier caps at 1, this never fires. Prefer `>= 1` or `== thresholdN`.

## Do

- **Fire after the success screen is shown**, not before it.
- **Add a short delay** (500ms–1s) so the success UI registers visually first.
- **Use `requestReview(in: UIWindowScene)`** — the deprecated `requestReview()`
  (no scene) still works but `requestReview(in:)` is scene-aware and
  recommended on iOS 14+.
- **Alternative: SwiftUI `@Environment(\.requestReview)`** — cleaner when you
  already have an `Environment` available (views/actions close to the UI).
  `SKStoreReviewController.requestReview(in:)` is preferred inside TCA effects
  where you don't have a View environment.
- **Let Apple rate-limit.** 3 prompts per 365 days is enforced system-wide.
  Don't add your own quota on top unless you have a specific reason.

## Apple's rate limit — what actually happens

| Scenario | Result |
|---|---|
| User saw prompt yesterday, you call `requestReview` again today | System silently skips (no prompt shown, no error) |
| User saw 3 prompts in the last 365 days | System silently skips |
| You bump app version | Counter does NOT reset |
| User actually submitted a review | System remembers and likely skips future prompts |

This is why you can call `requestReview` aggressively in code — the OS
protects the user from spam, you just need to call it at the right moments.

## Testing

- **TestFlight and simulator DO NOT show the prompt.** The prompt only
  appears in App Store / App Store distribution builds. Don't burn time trying
  to make it appear in dev.
- **In development, verify your code path runs** (add a `print` or
  `Logger.trace` immediately before `requestReview(in:)`) — that's the best
  you can do without an App Store build.
- **In UI tests,** the system prompt is not reachable (it's an OS-level
  sheet). Test the gating logic (`shouldPromptForReview(successCount:)`) as a
  pure function.

## Analytics

Track the **prompt trigger event** (not the review outcome — Apple doesn't
expose that):

```swift
AnalyticsClient.shared.track("review_prompt_triggered", [
    "success_count": "\(cards.count)",
    "app_version": Bundle.main.shortVersion,
])
```

Compare this event count to the App Store "ratings given in period" number
to estimate conversion rate. Rough industry benchmark: 1–3% of prompt
triggers → actual rating submission.

## Rollout checklist — when adding this to a new app

1. [ ] Identify the success moment (the action that makes users say "nice")
2. [ ] Add the gating count if you want a threshold (usually `>= 1`)
3. [ ] Ensure the success UI is shown BEFORE `requestReview(in:)` is called
4. [ ] Add 0.5–1s delay between success UI and prompt
5. [ ] Wire the analytics event for prompt-triggered
6. [ ] Ship in a TestFlight build; verify no crashes around the call site
7. [ ] Release to production; compare analytics event count to App Store
      ratings dashboard after 2 weeks

## One footgun to know about

`SKStoreReviewController.requestReview(in:)` will **silently do nothing** if
called from a process that isn't the foreground active app. This is usually
fine (the user must be in your app for the trigger to make sense) but
double-check for cases like:

- Background refresh completing with success
- Silent push notification causing a save
- Share-extension-initiated save

In those edge cases, queue the review-eligibility flag in `UserDefaults` and
trigger on the next foreground activation.

## Related

- Apple docs: [SKStoreReviewController.requestReview(in:)](https://developer.apple.com/documentation/storekit/skstorereviewcontroller/3566727-requestreview)
- App Review Guideline 1.1.7 (no custom "rate us" prompts)
- eCardify implementation: `eCardifySPM/Sources/GenericPassFeature/GenericPassForm.swift` — search for `SKStoreReviewController.requestReview`
