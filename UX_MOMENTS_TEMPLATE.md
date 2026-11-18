# [App Name] — UX Flow Catalog: Ads, Paywalls & Rating Prompts

This document catalogs all user touchpoints, trigger moments, rules, pacing policies, and orchestration logic for **Ads**, **Paywalls**, and **Rating Prompts** across the application.

---

## 1. Architectural Overview

All visual presentations, sheets, dialogs, and full-screen interstitials are orchestrated by **`UXFlowOrchestrator`** (backed by GraceAppsLibrary).

### Priority Pipeline Hierarchy
When multiple candidate actions are eligible at an evaluation moment (such as completing an activity or reaching a milestone), they execute sequentially in strict priority order with an automatic settling window between presentations:

| Priority Rank | Action Kind | Typical ID | Example Modal / Behavior |
|---|---|---|---|
| **1. Milestone / Celebration (750)** | `.sheet` / `.fullScreenCover` | `celebration` | Confetti, completion summary, streak celebration |
| **2. Paywall (500)** | `.sheet` | `paywall` | Direct-intent or milestone paywall sheet |
| **3. Review (250)** | `.systemDialog` / `.customAsync` | `rating_prompt` | Native StoreKit direct review prompt |
| **4. Ad (100)** | `.customAsync` | `interstitial_ad` | Full-screen AdMob interstitial |

---

## 2. Paywall Moments & Triggers

All paywall requests route through RevenueCat and `PaywallPacingEngine.shared`.

### Trigger Categories

#### A. Direct Intent (Always Approved for Free Users)
Explicit user actions expressing intent to unlock Pro features or remove ads:
* **`settings_upgrade`** (`SettingsView.swift`):
  * **Moment**: User taps "Upgrade" or Pro card in Settings.
  * **Behavior**: Opens native RevenueCat Paywall sheet.
* **`feature_gate_upgrade`**:
  * **Moment**: Free user taps a locked feature or reaches an endowment threshold.
  * **Behavior**: Opens native RevenueCat Paywall sheet.

---

## 3. App Store Rating & Review Moments

All rating prompt evaluations route through `ReviewPromptManager.shared` / StoreKit.

### Trigger Moments
* **`activity_completion`**:
  * **Moment**: Evaluated via `UXFlowOrchestrator` after reaching milestone checkpoint counts.
  * **Behavior**: Direct native StoreKit review prompt.
  * **Anti-Collision**: Suppressed while any modal or paywall is actively displayed. If a rating prompt fires, trailing interstitial ads in the flow are suppressed.
  * **Version Capping**: Enforces maximum **1 prompt per app release version**.

---

## 4. Full-Screen Ad Moments

Managed by `UniversalAdCoordinator.shared` and gated by `AdPacingEngine.shared`.

### Trigger Moments
* **`[trigger_name]`** (e.g. `fast_completed`):
  * **Moment**: Activity completed; requested via `UXAction.universalAd(trigger:)`.

### Ad Pacing & Protection Policies
1. **Flow Mutual Exclusion**: If a paywall or review prompt was presented during the completion flow, any trailing interstitial ad is **strictly dropped**.
2. **Cooldown**: Minimum safety cooldown between consecutive interstitial ad presentations.
3. **50-Minute Cache TTL**: Cached AdMob ads older than 50 minutes are automatically evicted.
4. **JIT Preloading**: Ads are preloaded Just-In-Time only when approved by `AdPacingEngine`.
5. **Pro Suppression**: 100% suppressed when user has Pro / Unlimited Access.

---

## 5. Flow Orchestration Matrix

| Screen / Event | Trigger Key | Celebration / Modal | Paywall Sheet | Rating Prompt | Interstitial Ad | Automated Test Verification |
|---|---|---|---|---|---|---|
| **Activity Completed** | `activity_completed` | Completion Summary | — | Direct StoreKit (if milestone eligible; suppresses ad) | Interstitial Ad (if not Pro & no review/paywall shown) | `testMatrixRow1_ActivityCompleted_AdPresentation` |
| **Settings Upgrade Card** | `settings_upgrade` | — | `PaywallView` (immediate on demand) | — | — | `testMatrixRow2_DirectIntentPaywall_FromSettings` |
| **Pro User Active** | `all_events` | As usual | Suppressed (Cards show "Pro Active") | Normal StoreKit rules | Strictly 100% Suppressed | `testMatrixRow3_ProUserTotalSuppression_AcrossApp` |

---

## 6. QA Verification Scenarios

Use these scenarios to verify paywall, rating prompt, and ad behavior during manual QA or automated UI testing.

### Scenario 1: Direct Intent Paywall from Settings
* **Goal**: Verify tapping upgrade presents paywall and returns cleanly.
* **Execution**: Tap Settings $\to$ Upgrade button.
* **Expected Outcome**: Paywall presents; dismissing restores Settings.

### Scenario 2: Activity Completion Interstitial Ad (Free User)
* **Goal**: Verify completed action presents ad when eligible.
* **Execution**: Complete activity with `-MockAdPresentation`.
* **Expected Outcome**: Ad appears and dismisses cleanly.

### Scenario 3: Pro User Total Suppression
* **Goal**: Verify Pro users experience zero ads and zero paywalls.
* **Execution**: Complete activity as Pro user.
* **Expected Outcome**: Zero interstitial ads and zero commercial paywalls appear.
