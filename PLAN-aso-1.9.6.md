# PLAN — v1.9.6 ASO release (2026-06-12)

## Goal
Ship v1.9.6 (build 39): scanner-angle ASO metadata refresh + review-prompt fix (one-shot → multi-moment), then submit for release.

## Tasks
- [x] Metadata: en-US/en-GB/en-CA — new subtitle "Business Card Scanner & QR" (26ch), keyword field exactly 100ch, description 2,468ch
- [x] Metadata: es-MX — deduped keyword field vs new en-US set (98ch)
- [x] Code: ReviewPromptGate in GenericPassFeature — AppStore.requestReview, stamps lastRequestDate only on actual attempt
- [x] Code: GenericPassForm first-card prompt → uses gate
- [x] Code: AppReducer scene-active second-chance prompt (auth + has-card gate, ≥5 sessions, ≥7 days, ≥60-day cooldown, cancellable on background/tokenRefreshFailed)
- [x] Build + tests pass (19/19; fixed 2 pre-existing test breaks: analyticsClient stub, ScreenshotTests stale products: arg)
- [ ] Review loop: Sonnet R1 ✓fixed, codex R1 ✓fixed (hasCards), Sonnet R2 ✓nits fixed, codex R2 ✓fixed (auth gate + cancel on tokenRefreshFailed), codex R3 in progress
- [ ] Bump MARKETING_VERSION 1.9.6, CURRENT_PROJECT_VERSION 39
- [ ] fastlane beta (build + TestFlight upload)
- [ ] fastlane release (metadata + submit for review, auto-release)

## Notes / decisions
- Subtitle targets "business card scanner" UNSPLIT (audit: top-10 includes apps with 8/41/472 ratings — winnable at 0 ratings). "Business Card" duplication from title is the accepted cost of forming the phrase in a high-weight field.
- User's draft keywords minus `qr` (now in subtitle — Apple combines fields within a locale, dupe = wasted chars) and minus `linkedin` (Apple 2.3.7 trademark-keyword rejection risk; searchers for "linkedin" want LinkedIn). Added `maker,holder` → exactly 100 chars.
- Free tier caps at 1 card → card-count milestones (count==3) would never fire for most users; second prompt moment must be session/time-based at app-active.
- Other 8 locales untouched this round: subtitles are native-quality (RU-lesson house rule — don't churn native copy without native review); their keyword fields already carry localized scanner/NFC terms.
- en-AU not present locally and not enabled in ASC — out of scope.
