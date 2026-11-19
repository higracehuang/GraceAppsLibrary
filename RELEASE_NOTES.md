# GAL Release Notes

Release notes for GraceAppsLibrary, newest first. One section per release,
each change listed with the feature name first.

## 1.40.1 — Nov 19, 2026

- UX Flow: Release notes now run through the orchestrator, with a settled callback, priority queue re-sorting, and duplicate actions removed by ID.
- Paywall: New UniversalPaywallPresenter and UXAction.paywall, so the paywall presents through the orchestrator.
- Release Notes: Launch checks no longer re-run on tab switches, and the sheet dismisses before the paywall opens.
- AdMob: Showing ads is internal now, so ads only present through the orchestrator.
- Logger: New error-level convenience method in GraceLogger.
- CI / Fastlane: Added reusable `sync-appstore.yml` GitHub Actions workflow for cross-app metadata and screenshot syncing.

## 1.40.0 — Nov 18, 2026

- AdMob: New GraceAppsLibraryAdMob product with a universal ad coordinator, just-in-time ad preload, and session reset.
- RevenueCat: New GraceAppsLibraryRevenueCat product with a universal purchase coordinator and a debug section.
- Paywall: New universal paywall sheet and view modifiers, and purchases are recorded in the pacing engine automatically.
- Review Prompt: Two prompt styles, a 90-day cooldown, patch-version protection, and milestone-based prompts.
- Subscription: New universal subscription section for settings screens, localized to the GAK standard.
- Debug Menu: New universal debug menu, debug link, and developer section for settings screens.
- UX Flow: New UX moments template, and a validator that checks UI test coverage of UX moments.
- Fastlane: Centralized Fastfile for cross-app automation.

## 1.39.1 — Nov 13, 2026

- UX Flow: Action IDs are strongly typed now (UXActionID).
- Screenshots: Better detection of when a screenshot is ready to capture.

## 1.39.0 — Nov 13, 2026

- UX Flow: New UXFlowOrchestrator runs paywalls, review prompts, and ads in one queue, with tags, a standard policy, and scoped flows.
- Ad Pacing: New AdPacingEngine and PaywallPacingEngine control how often ads and paywalls appear.
- Review Prompt: New ratingPrompt action, and a helper to open the App Store review page.
- Testing: Mock view controllers for the review prompt and interstitial ads.
- Docs: README covers the orchestrator and the pacing engines.

## 1.38.1 — Nov 10, 2026

- Review Prompt: Fixed the rating prompt being cancelled when a sheet dismisses, and added a simple no-argument way to show the native prompt.
- CI: Runner image updated to macos-15.

## 1.38.0 — Nov 4, 2026

- Screenshots: Apple Watch screenshots are supported in the generator, with balanced spacing and a circular watch backdrop.
- Screenshots: Dual-device slides with a secondary mockup, brand badge headers, and fixed carousel alignment and scrolling.

## 1.37.0 — Nov 4, 2026

- Version Display: The version string no longer shows a Debug or Release prefix in screenshots and release builds.

## 1.36.0 — Nov 2, 2026

- Preview Videos: New tooling to record App Store preview videos, with an overlay compositor and a 30fps encoder.
- Docs: Translation principles, storefront check, and versioning docs moved to GraceAppKnowledge.

## 1.35.0 — Oct 29, 2026

- Screenshots: New panoramic App Store row view with scale controls, plus layout fixes so slides no longer clip or overflow.
- Onboarding: Step transitions animate by default, and swiping between steps can be turned off.

## 1.34.0 — Oct 28, 2026

- Screenshots: New hero slide type for the renderer, with 3D flashcard styling and an iPad layout with fanned cards and a bento grid.
- Docs: Fastlane playbook with directory standards, metadata specs, and CI/CD automation.
