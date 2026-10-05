# Grace Apps Onboarding Principles & Standards

A standardized playbook for crafting delightful, high-converting, and respectful onboarding experiences across all Grace Apps (`DialInPourOver`, `DialInEspresso`, `FastingGirls`, etc.).

---

## 🧭 Core Growth Philosophy: The 2-Minute Window

Industry data and RevenueCat benchmarks show that **over 80% of subscription trial starts occur on Day 0 within the first 2 minutes of installation**. 

* **Onboarding IS the Movie:** Do not treat onboarding as a skipped "trailer" or setup hurdle. The opening moments are where intent, brand perception, and purchase decisions crystallize.
* **Anticipatory Trust:** Users judge apps not by past features, but by what they *feel* the app will deliver for them. Sell the **outcome and promise** before the proof.
* **High-Leverage Compounding:** A 5% lift in onboarding conversion multiplies the impact of every single download before downstream retention curves ever begin.

---

## 🧭 The 6 Core Pillars

### 1. 📖 Inform & Prime (Outcomes Over Specs)
Communicate core value drivers in scannable, bite-sized chunks so users instantly grasp the transformation the app enables.
* **Do:**
  * Focus on outcomes and user benefits (e.g., *"Dial in repeatable, cafe-quality espresso every morning"*, *"Effortless bean tracking with AI autofill"*).
  * Set transparent expectations upfront (e.g., *"Takes less than 60 seconds to personalize"*).
  * Frame value around user aspiration and daily craft.
* **Avoid:**
  * Dense feature lists or dry technical specifications.
  * Internal terminology, branded jargon, or complex mechanics before trust is established.

---

### 2. ✨ Have Good First Impressions
Establish quality, fluidity, and visual excellence from the very first frame.
* **Do:**
  * Reuse real production views and components (`CoffeeSummaryCardView`, `PourStepContent`) so the onboarding directly reflects the app's real interface.
  * Use fluid spring animations, subtle scaling effects, and responsive haptics.
  * Adhere strictly to Apple Human Interface Guidelines (HIG), native typography (`.rounded`), Dynamic Type, and high contrast.
* **Avoid:**
  * Generic or artificial mockup illustrations that misrepresent the actual UI.
  * Choppy, un-animated layout jumps between slides.

---

### 3. 🤝 Build Trust & Lower Friction
Earn user confidence by demonstrating respect for their time, autonomy, and privacy.
* **Do:**
  * Embrace local-first data persistence with offline readiness and zero forced account sign-ups.
  * Provide transparent exit paths (*"Skip for Now"* / *"Set Up Later"*) on action steps so users never feel trapped.
  * Clearly explain why preferences (e.g., temperature units or camera permissions) are requested.
* **Avoid:**
  * Mandatory account creation blockers or rigid data-entry traps.
  * Cluttered forms that ask for unnecessary information before delivering value.

---

### 4. 🎛️ Personalize via Dialogue (Two-Way Interaction)
Transform onboarding into an engaging dialogue rather than a one-way lecture.
* **Do:**
  * Ask 1–2 lightweight interactive questions (e.g., primary coffee style, brew goal, temperature scale: `°C` vs `°F`).
  * Use their choices immediately to dynamically customize subsequent templates and default recipes.
  * Leverage the **effort-justification effect**: when users actively participate, they place higher value on the resulting experience.
* **Avoid:**
  * Long multi-step surveys that create onboarding fatigue.
  * Making assumptions that force international users to hunt through Settings later.

---

### 5. 🚀 Micro-Commitments & Identity Priming
Utilize commitment psychology (Cialdini's consistency principle & self-perception theory) to guide users from interest to ownership.
* **Do:**
  * Incorporate a low-friction **micro-commitment cue** before reaching the paywall or final launchpad (e.g., *"I'm ready to dial in my espresso"*, 1-tap goal pledge, or saving a pre-filled starting recipe).
  * Trigger self-identification: encourage users to see themselves as someone who follows through on their coffee or habit goals.
  * Provide pre-filled starting templates (e.g., *"My Daily Pour-Over"*) that can be saved with **1 tap**.
* **Avoid:**
  * Blank forms with 10 empty text fields that feel like administrative homework.
  * Pressuring or deceiving users into false commitments.

---

### 6. 🪄 Show Magic & Launch into Value
Deliver an immediate emotional payoff and clear bridge to the app's core power.
* **Do:**
  * Celebrate their setup with a live, dynamic confirmation state (e.g., displaying their newly created recipe in the production parameter grid with a glowing *"Ready to Brew"* status).
  * Gracefully handle both branches:
    * **If Created:** Confirm the recipe is locked and loaded for their first brew.
    * **If Skipped:** Present an inviting launchpad canvas showcasing how easy it is to add beans or tap `+` anytime.
  * Provide a clear primary action (*"Start Brewing"* / *"Enter App"*) for a smooth transition.
* **Avoid:**
  * Anticlimactic dismissals that dump the user onto an empty screen without context.

---

## 🚫 4 Onboarding Funnel Pitfalls to Avoid

1. **Burying the Value Proposition & Paywall:** Hiding the core outcome or upgrade benefits behind excessive filler slides. If users lose momentum before seeing the payoff, they bounce.
2. **Information / Spec Overload:** Listing what the code does rather than what the user achieves.
3. **Overusing Branded Language:** Relying heavily on proprietary internal names that mean nothing to first-time downloaders.
4. **Emotional Flatness & Monologues:** Delivering a static slide show with no interactive questions, pledges, or aspiration.

---

## 📊 Privacy-First Funnel Telemetry (Strategy B)

Grace Apps implements a **100% privacy-preserving, zero-PII event tracking standard** powered by `OnboardingTracker` in `GraceAppsLibrary` and [TelemetryDeck](https://telemetrydeck.com) (or local diagnostics).

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