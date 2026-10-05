# Grace Apps Onboarding Principles & Standards

A standardized playbook for crafting delightful, high-converting, and respectful onboarding experiences across all Grace Apps (`DialInPourOver`, `DialInEspresso`, `FastingGirls`, etc.).

---

## 🧭 Core Growth Philosophy: The 2-Minute Window

Industry benchmarks (RevenueCat & case studies like Five Minute Journal / Flo) show that **over 80% of subscription trial starts occur on Day 0 within the first 2 minutes of installation**. 

* **Onboarding IS the Movie:** Do not treat onboarding as a skipped "trailer" or setup chore. The opening moments are where user intent, brand perception, and conversion decisions crystallize.
* **Jobs-to-be-Done (JTBD):** Users don't buy feature lists or database schemas; they hire an app to solve a specific job or achieve a daily transformation.
* **Anticipatory Trust:** Users judge apps by what they *feel* the app will deliver for them. Sell the **outcome and promise** before the proof.
* **High-Leverage Compounding:** A 5% lift in onboarding conversion multiplies the impact of every single download before downstream retention curves ever begin.

---

## 🧭 The 7 Core Pillars

### 1. 📖 Frame Around Jobs-to-be-Done (JTBD)
Communicate value through the specific "job" the user is hiring the app to do rather than technical mechanics.
* **Do:**
  * Frame value around user aspiration and daily craft (e.g., *FastingGirls*: *"Fast in sync with your hormones to lose weight without burnout"*; *DialInEspresso*: *"Dial in repeatable, cafe-quality espresso without wasting beans"*).
  * Set transparent expectations upfront (e.g., *"Takes less than 60 seconds to personalize"*).
* **Avoid:**
  * Dry technical specifications (e.g., *"Imports `HKCategoryTypeIdentifier.menstrualFlow`"* or *"Stores dose and grind parameters"*).
  * Internal terminology, branded jargon, or complex mechanics before trust is established.

---

### 2. ✨ Deliver Good First Impressions
Establish quality, fluidity, and visual excellence from the very first frame.
* **Do:**
  * Reuse real production views and components (`CoffeeSummaryCardView`, `PourStepContent`) so the onboarding directly reflects the app's real interface.
  * Use fluid spring animations, subtle scaling effects, and responsive haptics.
  * Adhere strictly to Apple Human Interface Guidelines (HIG), native typography (`.rounded`), Dynamic Type, and high contrast.
* **Avoid:**
  * Generic or artificial mockup illustrations that misrepresent the actual UI.
  * Choppy, un-animated layout jumps between slides.

---

### 3. ⭐️ Anchor Early Social Proof & Credibility
Incorporate real social proof early in the journey *before* asking for heavy commitments or showing a paywall.
* **Do:**
  * Feature a compact, high-signal testimonial quote, App Store rating badge, or community stat (e.g., *"★★★★★ 'Finally an app that knows when NOT to fast before my period!' — Sarah M."*).
  * Position social proof right alongside the core value proposition to ease first-time user skepticism.
* **Avoid:**
  * Hiding credibility cues only on the paywall screen.
  * Cluttered, multi-paragraph text walls that distract from the primary flow.

---

### 4. 🤝 Build Trust & Zero-Blocker Permission Priming
Earn user confidence by demonstrating respect for their time, autonomy, and privacy.
* **Do:**
  * Always prime permissions (Apple Health, Notifications, Camera) with the direct **user benefit** before triggering the system prompt.
  * **Provide Zero-Blocker Fallbacks:** Never allow a permission denial or empty system state (e.g., 0 HealthKit records) to block the funnel. Always offer a **1-tap in-app manual fallback** (e.g., *"Set last period date manually (1 tap)"* or *"Skip for now"*).
  * Embrace local-first data persistence with offline readiness and zero forced account sign-ups.
* **Avoid:**
  * Dead-end screens that instruct users to leave the app to fix settings.
  * Mandatory account creation blockers or rigid data-entry traps.

---

### 5. 🎛️ Closed-Loop Personalization & Dialogue
Transform onboarding into an engaging two-way dialogue where choices actively shape the product.
* **Do:**
  * Ask 1–2 lightweight interactive questions (e.g., primary wellness/coffee goal, temperature scale: `°C` vs `°F`).
  * **Closed-Loop Rule:** Use their selections to dynamically pre-configure and highlight recommended templates (e.g., selecting *"Gentle Hormone Health"* pre-selects *"Simple Reset"*).
  * Leverage the **effort-justification effect**: when users actively participate, they place higher value on the resulting experience.
* **Avoid:**
  * Multi-step questionnaires with no visible payoff or impact on default settings.
  * Making assumptions that force international users to hunt through Settings later.

---

### 6. 🚀 Micro-Commitments & Identity Priming
Utilize commitment psychology (Cialdini's consistency principle & self-perception theory) to guide users from interest to ownership.
* **Do:**
  * Incorporate a low-friction **micro-commitment cue** before reaching the paywall or final launchpad (e.g., *"I'm ready to dial in my espresso"*, 1-tap goal pledge, or saving a pre-filled starting recipe).
  * Trigger self-identification: encourage users to see themselves as someone who follows through on their wellness or coffee craft goals.
  * Provide pre-filled starting templates that can be saved with **1 tap**.
* **Avoid:**
  * Blank forms with 10 empty text fields that feel like administrative homework.
  * Pressuring or deceiving users into false commitments.

---

### 7. 🪄 Show Magic & Launch into Value
Deliver an immediate emotional payoff and clear bridge to the app's core power.
* **Do:**
  * Celebrate their setup with a live, dynamic confirmation state (e.g., displaying their newly created recipe or fasting cycle in the production parameter grid with a glowing *"Ready to Brew"* status).
  * Gracefully handle both branches:
    * **If Created:** Confirm the setup is locked and loaded.
    * **If Skipped:** Present an inviting launchpad canvas showcasing how easy it is to tap `+` anytime.
  * Provide a clear primary action (*"Start Fasting"* / *"Start Brewing"* / *"Enter App"*) for a seamless transition.
* **Avoid:**
  * Anticlimactic dismissals that dump the user onto an empty screen without context.

---

## 🚫 4 Onboarding Funnel Pitfalls to Avoid

1. **Burying the Value Proposition & Paywall:** Hiding the core outcome or upgrade benefits behind excessive filler slides. If users lose momentum before seeing the payoff, they bounce.
2. **Information / Spec Overload:** Listing what the code does rather than what the user achieves (ignoring JTBD).
3. **Overusing Branded Language:** Relying heavily on proprietary internal names that mean nothing to first-time downloaders.
4. **Emotional Flatness & Monologues:** Delivering a static slide show with no social proof, interactive questions, pledges, or aspiration.

---

## 📊 Privacy-First Funnel Telemetry (Strategy B)

Grace Apps implements a **100% privacy-preserving, zero-PII event tracking standard** powered by `OnboardingTracker` in `GraceAppsLibrary` and [TelemetryDeck](https://telemetrydeck.com).

### 1. Standard Funnel Event Schema

| Event Name | Key Parameters | Purpose |
| :--- | :--- | :--- |
| `onboarding_started` | `app_version`, `entry_point` | Marks the top of the funnel (Day 0 install) |
| `onboarding_step_viewed` | `step_index`, `step_name`, `total_elapsed_sec` | Pinpoints exact step drop-off rates and time spent |
| `onboarding_micro_commitment` | `commitment_type`, `commitment_value`, `step_index` | Measures user identity priming and intent |
| `onboarding_step_skipped` | `step_index`, `step_name` | Identifies optional steps bypassed |
| `onboarding_paywall_viewed` | `source`, `offering_id`, `total_elapsed_sec` | Tracks bridge between onboarding completion and monetization |
| `onboarding_completed` | `total_duration_sec`, `did_perform_action`, `final_step_index` | Base metric for funnel completion |

### 2. Built-in TelemetryDeck Integration

`GraceAppsLibrary` directly bundles `TelemetryDeck`. Any Grace App can initialize it with a single line during app launch:

```swift
import SwiftUI
import GraceAppsLibrary

@main
struct YourApp: App {
    init() {
        // Automatically initializes TelemetryDeck & binds OnboardingTracker
        OnboardingTracker.shared.configureWithTelemetryDeck(appID: "YOUR-TELEMETRYDECK-APP-ID")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

*(Optional)* If you wish to use a custom logger or other analytics provider, you can conform to `OnboardingAnalyticsProvider` and call `OnboardingTracker.shared.configure(provider: MyCustomProvider())`.

### 3. Key Conversion Ratios & Target Benchmarks

* **Funnel Completion Rate:** $\frac{\text{onboarding\_completed}}{\text{onboarding\_started}} \ge \mathbf{85\%}$
* **Install-to-Paywall Rate:** $\frac{\text{onboarding\_paywall\_viewed}}{\text{onboarding\_started}} \ge \mathbf{75\%}$
* **Micro-Commitment Engagement:** $\frac{\text{onboarding\_micro\_commitment}}{\text{onboarding\_started}} \ge \mathbf{70\%}$
* **Day-0 Trial Conversion:** $\frac{\text{trial\_started (Day 0)}}{\text{app\_installs}} \ge \mathbf{10\%\text{--}15\%}$

---

## 🏗 Technical Implementation Standards

1. **GraceAppsLibrary Integration:**
   * Build onboarding flows using `OnboardingContainer`, `OnboardingSlideLayout`, `OnboardingCoordinator`, `OnboardingButtons`, and `OnboardingTracker`.
2. **Version-Aware Onboarding:**
   * Use `OnboardingManager.recordOnboardingCompleted(forVersion:)` and `shouldShowOnboarding(forVersion:)` to trigger feature highlights on major version upgrades.
3. **Accessibility & Dynamic Type:**
   * Support Large Dynamic Type sizes and VoiceOver headers.
   * Respect `@Environment(\.accessibilityReduceMotion)`.
4. **Test Coverage:**
   * Write unit tests covering all coordinator steps, preference persistence, decision branches (saved vs skipped), completion flags, and telemetry event firing.