# Grace Apps Onboarding Principles & Standards

A standardized playbook for crafting delightful, high-converting, and respectful onboarding experiences across all Grace Apps (`DialInPourOver`, `DialInEspresso`, etc.).

---

## 🧭 The 6 Core Pillars

### 1. 📖 Inform
Communicate core value drivers in scannable, bite-sized chunks so users instantly grasp what the app solves and how it fits their workflow.
* **Do:**
  * Highlight the primary features (e.g., Bean Logging + AI Autofill, Precision Pour Schedules).
  * Set transparent expectations upfront (e.g., *"Takes less than a minute"*).
  * Focus on outcomes and user benefits rather than dry technical specs.
* **Avoid:**
  * Walls of dense text or multi-paragraph feature lists.
  * Overwhelming the user with advanced edge-case features during first launch.

---

### 2. ✨ Have Good First Impressions
Establish quality, fluidity, and visual excellence from the very first frame.
* **Do:**
  * Reuse real production views and components (`CoffeeSummaryCardView`, `PourStepContent`) so the onboarding matches the app's real interface.
  * Use fluid spring animations, subtle scaling effects, and responsive haptics.
  * Adhere strictly to Apple Human Interface Guidelines (HIG), native typography (`.rounded`), Dynamic Type, and high contrast.
* **Avoid:**
  * Generic or artificial mockup illustrations that misrepresent the actual UI.
  * Choppy, un-animated layout jumps between slides.

---

### 3. 🤝 Build Trust
Earn user confidence by demonstrating respect for their time, autonomy, and privacy.
* **Do:**
  * Embrace local-first data persistence with offline readiness and zero forced account sign-ups.
  * Provide transparent exit paths (*"Skip for Now"* / *"Set Up Later"*) on action steps so users never feel trapped.
  * Clearly explain why preferences (e.g., temperature units or camera/link permissions) are requested.
* **Avoid:**
  * Mandatory blockers, intrusive paywalls on step 1, or rigid data-entry traps.
  * Cluttered forms that ask for unnecessary data before delivering value.

---

### 4. 🎛️ Personalize
Tailor the app to the user's regional gear, habits, and preferences early in the journey.
* **Do:**
  * Collect essential regional preferences (e.g., Temperature Scale: `°C` vs `°F`, Scale Display Mode) with 1-tap interactive switches.
  * Use their choices to dynamically customize subsequent templates and default recipes.
  * Ensure all selections are immediately persisted to `@AppStorage` / `UserDefaults`.
* **Avoid:**
  * Making assumptions that force international users to dig through Settings later.
  * Long multi-step questionnaires that cause onboarding fatigue.

---

### 5. 🚀 Create Excitement
Transform passive reading into active, exciting ownership with ultra-fast time-to-value.
* **Do:**
  * Offer smart, pre-filled starting templates (e.g., *"My Daily Pour-Over"*) that users can save with **1 tap** or fine-tune.
  * Connect directly to their passion for coffee craft and flavor discovery.
  * Give users an immediate sense of accomplishment and progression.
* **Avoid:**
  * Presenting empty, blank forms with 10 required fields that feel like administrative homework.
  * Generic presets that don't allow personal customization.

---

### 6. 🪄 Show Magic at the End
Deliver an immediate emotional payoff and sneak peek of the app's core power in action.
* **Do:**
  * Celebrate their setup with a live, dynamic confirmation state (e.g., displaying the newly created recipe in the production parameter grid with a glowing *"Ready to Brew"* status).
  * Gracefully handle both branches:
    * **If Created:** Confirm the recipe is locked and loaded for their first brew.
    * **If Skipped:** Present an inviting launchpad canvas showcasing how easy it is to add beans or tap `+` anytime.
  * Provide a clear primary action (*"Start Brewing"* / *"Enter App"*) for a smooth transition.
* **Avoid:**
  * Anticlimactic dismissals that dump the user onto an empty screen without context.

---

## 🏗 Technical Implementation Standards

1. **GraceAppsLibrary Integration:**
   * Build onboarding flows on top of `GraceAppsLibrary`'s `OnboardingContainer`, `OnboardingSlideLayout`, `OnboardingCoordinator`, and `OnboardingButtons`.
2. **Version-Aware Onboarding:**
   * Use `OnboardingManager.recordOnboardingCompleted(forVersion:)` and `shouldShowOnboarding(forVersion:)` to support feature highlights on major version upgrades.
3. **Accessibility & Dynamic Type:**
   * Support Large Dynamic Type sizes and VoiceOver headers.
   * Respect `@Environment(\.accessibilityReduceMotion)`.
4. **Test Coverage:**
   * Write unit tests covering all coordinator steps, preference persistence, decision branches (saved vs skipped), and completion flags.