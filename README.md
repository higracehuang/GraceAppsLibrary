# GraceAppsLibrary

A Swift package that provides information about Grace Apps' iOS applications, including names, descriptions, and App Store links. Supports multiple languages including English, Japanese, Simplified Chinese, German, Spanish, and French.

## Features

- Get information about all Grace Apps
- Localized app names and descriptions in multiple languages
- App Store links
- Option to exclude specific apps from the list
- iOS 14+ support
- Built-in views for displaying apps, feedback, release notes, FAQs, and emoji input
- Shared Onboarding framework (`OnboardingContainer`, `OnboardingSlideLayout`, `OnboardingCoordinator`)
- Smart review prompting (`ReviewPromptManager`) with 2-step pre-filter & feedback redirection
- Automated App Store Screenshot framework (`ScreenshotPresetProvider`, `ScreenshotEngine`, `DebugScreenshotSection`, and CLI runner script)

## Installation

1. Add this package to your Xcode project using Swift Package Manager.
1. Import the package in your Swift file:

```swift
import GraceAppsLibrary
```
## Usage

The library provides ready-to-use SwiftUI views for common settings and about screens.

#### ReleaseNotesManager
`ReleaseNotesManager` provides manual control over release notes version tracking:

```swift
// Check if notes should be shown for a set of release notes
let shouldShow = ReleaseNotesManager.shared.shouldShow(releaseNotes: myNotes)

// Mark the current version as viewed manually
ReleaseNotesManager.shared.markCurrentVersionAsViewed()
```


### Usage

#### 1. Display Apps & Feedback
Use the built-in views to display the app list or feedback section:

```swift
GraceAppsView()           // App list
FeedbackToGraceView()    // Feedback section
```

#### 2. Show Release Notes
Use the `.graceReleaseNotes` modifier on any view. It automatically handles version checking and persistence (marking as viewed):

```swift
.graceReleaseNotes(
    releaseNotes: [
        ReleaseNote(
            version: "2.1.0",
            items: [
                ReleaseNoteItem(text: "New AI feature", isPaidFeature: true)
            ],
            heroImageName: "AppIcon"
        )
    ],
    isPaidUser: purchaseStore.isPro, // Hides paywall CTA if true
    tierName: "Unlimited Access",    // Custom name for premium tier
    paywallAction: {                // Action for the upgrade button
        showPaywall = true 
    }
)
```

> [!TIP]
> The paywall CTA button will automatically appear for the **first release note in the list that contains a paid feature** (`isPaidFeature: true`), ensuring a clean UI.
> This modifier handles both "Done" button and swipe-to-dismiss, ensuring users don't see the same notes twice.

#### 3. Release Notes CTAs & Promotion Usages

`ReleaseNote` supports rich action buttons (CTAs) for cross-app promotion, website links, custom actions, and paywalls:

##### A. Cross-App Promotion (Sister Apps)
Promote companion or sister apps (e.g. promoting *Dial In Pourovers* from *Dial In Espresso*) with an App Store link. Since `ctaURL` is provided, this button is displayed for all users (both free and paid):

```swift
ReleaseNote(
    version: "1.19.0",
    items: [
        ReleaseNoteItem(text: "Seamless bean sharing with Dial In Pourovers!"),
        ReleaseNoteItem(text: "Your beans now automatically sync between both apps.")
    ],
    heroImageName: "ReleaseNotes/DIPOBanner",
    heroImageURL: URL(string: "https://apps.apple.com/app/idYOUR_APP_ID"), // Optional: taps on the hero image open this URL (defaults to ctaURL)
    ctaTitle: "Get Dial In Pourovers",
    ctaURL: URL(string: "https://apps.apple.com/app/idYOUR_APP_ID"),
    ctaSystemImage: "arrow.down.app"
)
```

##### B. External Website Links (Guides, Blog Posts, Documentation)
Link users to a website, user manual, or blog post using `ctaURL` and an optional icon like `"safari"` or `"arrow.up.right"`:

```swift
ReleaseNote(
    version: "1.18.0",
    notes: [
        "New brewing guide published on our website.",
        "Detailed extraction ratios and grinder calibration charts."
    ],
    ctaTitle: "Read the Brewing Guide",
    ctaURL: URL(string: "https://ujiapps.com/guides/dial-in-espresso"),
    ctaSystemImage: "safari"
)
```

##### C. In-Text Markdown Links
Each `ReleaseNoteItem.text` is a SwiftUI `LocalizedStringKey`. You can place clickable Markdown links directly in bullet points:

```swift
ReleaseNote(
    version: "1.17.0",
    notes: [
        "Check out our [Web Companion](https://ujiapps.com) for bean analytics.",
        "Join our community discussion on [Discord](https://discord.gg/example)."
    ]
)
```

##### D. Custom Action with Free/Paid Targeting
You can supply a custom closure with `ctaAction`. By default:
- Notes with `isPaidFeature: true` items hide the CTA for paid users (`isPaidUser == true`).
- Notes with free items show the CTA to all users.
- You can explicitly override this with `ctaRequiresUnpaidUser`:

```swift
ReleaseNote(
    version: "1.16.0",
    notes: ["Exclusive launch discount for free users."],
    ctaTitle: "Claim Special Offer",
    ctaRequiresUnpaidUser: true, // Only visible when isPaidUser == false
    ctaAction: {
        showSpecialOfferSheet = true
    }
)
```

#### 4. Display "What's New" in Settings
If you want to allow users to manually trigger the Release Notes view (e.g., from a Settings screen):

```swift
WhatIsNewView(releaseNotes: [
    ReleaseNote(version: "2.0.0", items: [
        ReleaseNoteItem(text: "New features!"),
        ReleaseNoteItem(text: "Bug fixes.")
    ])
])
```

This view provides a simple button with a sparkles icon that pops up the release notes when clicked.

#### 5. Emoji Input Support
Use `EmojiTextField` to provide a focused emoji selection experience. It automatically forces the emoji keyboard and restricts input to a single character.

```swift
@State private var emoji: String = "✨"

EmojiTextField(
    text: $emoji,
    placeholder: "Select Emoji",
    font: .systemFont(ofSize: 40),
    textAlignment: .center
)
.frame(height: 80)
```

#### 6. Show FAQs
Use `FAQNavigationView` to easily add a Frequently Asked Questions section to your app:

```swift
FAQNavigationView(sections: [
    FAQSection(
        title: "Basics",
        items: [
            FAQItem(question: "How does this work?", answer: "It is very simple."),
            FAQItem(question: "Is it free?", answer: "Yes, the basic version is free.")
        ]
    )
])
```

#### 7. About App Section
Use `AboutAppSectionView` to add a ready-made "About" section to your Settings screen. It displays the current app version, a "What's New" button, a link to rate the app, and a share sheet for the App Store page — all without any additional dependencies.

**Parameters**

| Parameter | Type | Description |
|---|---|---|
| `appStoreId` | `String` | Your numeric App Store ID. |
| `releaseNotes` | `[ReleaseNote]` | The release notes array. |
| `isPaidUser` | `Bool` | Whether the user is a paid user (hides CTA). |
| `tierName` | `LocalizedStringKey` | The name of the premium tier. |
| `paywallAction` | `() -> Void` | The action to trigger the paywall flow. |

```swift
AboutAppSectionView(
    appStoreId: "1234567890",
    releaseNotes: [
        ReleaseNote(version: "2.0.0", items: [
            ReleaseNoteItem(text: "New features!"), 
            ReleaseNoteItem(text: "Bug fixes.")
        ]),
        ReleaseNote(version: "1.0.0", items: [
            ReleaseNoteItem(text: "Initial release.")
        ])
    ]
)
```

> [!NOTE]
> `AboutAppSectionView` reads `CFBundleDisplayName` / `CFBundleName` and `CFBundleShortVersionString` / `CFBundleVersion` from `Bundle.main` automatically, so no additional configuration is needed.

> [!TIP]
> The "Share This App" row uses SwiftUI's native `ShareLink`, which requires **iOS 16+**. Make sure your deployment target is set accordingly.

#### 8. Language Setting Link
Use `LanguageSettingLinkView` to provide a direct link to the app's settings in the System Settings app, allowing users to quickly change the app's language. It displays the current preferred language as a badge (iOS 15+) or trailing text (iOS 14).

```swift
LanguageSettingLinkView()
```

#### 9. Help & Support Section
Use `HelpSupportSectionView` to provide a unified help section in your Settings screen. It can optionally show FAQs, a link to "Sources & References", and a feedback link.

```swift
HelpSupportSectionView(
    faqSections: myFAQSections, // Optional: Shows FAQNavigationView if provided
    sourceSections: mySourceSections, // Optional: Shows NavigationLink to SourcesView if provided
    sourceDisclaimer: "Optional disclaimer text", // Optional: Used in SourcesView
    showFeedback: true // Optional: Defaults to true, shows FeedbackToGraceNavigationView
)
```

#### 10. About Developer Section
Use `AboutDeveloperSectionView` to add a ready-made "About the App Developer" section to your Settings screen. It provides a navigation link to the developer's other apps.

```swift
AboutDeveloperSectionView(
    excludingAppId: "id1234567890" // Optional: Excludes current app from the list
)
```

#### 11. Review Prompt Manager
Use `ReviewPromptManager` to politely prompt users for App Store reviews while directing unhappy users to feedback channels instead of leaving negative App Store ratings.

It features a 2-step pre-filter dialog (*"Are you enjoying [AppName]?"*):
* **Positive Response ("Yes, I am 🥰")**: Opens Apple's native StoreKit review prompt (`AppStore.requestReview`).
* **Negative Response ("Not really")**: Triggers support feedback (pre-filled email to support or a custom `onNegativeFeedback` closure).

```swift
// Call in App Delegate or App init to reset engagement counts on new app versions
ReviewPromptManager.appInit()

// Request review after significant user actions (default checkpoint: 5 engagements)
ReviewPromptManager.shared.requestReview()

// Custom negative feedback redirection (e.g. open custom feedback sheet)
ReviewPromptManager.shared.requestReview {
    showFeedbackSheet = true
}

// Throttled daily review request
ReviewPromptManager.shared.requestReviewDaily()

// Directly present StoreKit review prompt without pre-filter alert
ReviewPromptManager.shared.requestDirectNativeReview()
```

> [!NOTE]
> `ReviewPromptManager` automatically tracks per-version review prompts and engagement counters in `UserDefaults`, ensuring users are never nagged repeatedly on the same app version.

#### 12. Shared Onboarding System
Use the Onboarding system to build multi-step carousel flows with customizable hero cards, animated capsule page indicators, safe action trays, and step coordination.

##### Components:
* **`OnboardingContainer`**: Paging shell that wraps slides, provides configurable top progress bars or animated capsule page indicators (`indicatorStyle: .progressBar`, `.segmentedProgressBar`, `.dots`), and maintains a stable bottom action tray to prevent layout jumping.
* **`OnboardingProgressBar`**: Continuous smooth progress bar with spring animations and reduced motion accessibility.
* **`OnboardingSegmentedProgressBar`**: Segmented progress bar reflecting individual steps.
* **`OnboardingSlideLayout`**: Standard hero card (with custom content & optional trailing badge) paired with a bottom narrative section (Title + Subtitle) and dynamic type accessibility protection.
* **`OnboardingPrimaryButton`**: Full-width primary CTA button with built-in loading spinner support (`isLoading`).
* **`OnboardingSecondaryButton`**: Secondary text button for "Skip for now" with built-in translations in English, Spanish, French, Simplified Chinese, German, and Japanese.
* **`OnboardingCoordinator`**: Step coordinator tracking `currentStep`, `totalSteps`, `progress`, navigation (`next()`, `previous()`, `goTo()`, `skip()`, `complete()`), and lifecycle callbacks (`onStepChange`, `onComplete`, `onSkip`).
* **`OnboardingManager`**: Persistence and version-based onboarding presentation checker (`shouldShowOnboarding(forVersion:)`).

##### Example Usage:

```swift
import SwiftUI
import GraceAppsLibrary

struct AppOnboardingView: View {
    @StateObject private var coordinator = OnboardingCoordinator(totalSteps: 3)
    @AppStorage("has_completed_onboarding") private var hasCompletedOnboarding: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        OnboardingContainer(
            coordinator: coordinator,
            backgroundColor: Color(.systemBackground),
            indicatorActiveColor: .primary
        ) {
            // Slide 0: Welcome
            OnboardingSlideLayout(
                cardTitle: "Welcome",
                narrativeTitle: "Track Your Daily Rhythm",
                narrativeSubtitle: "Understand your progress with clear, beautiful trends."
            ) {
                MyWelcomeHeroView()
            }
            .tag(0)
            
            // Slide 1: Feature Highlights / Quiz
            OnboardingSlideLayout(
                cardTitle: "Personalize",
                narrativeTitle: "Choose Your Focus",
                narrativeSubtitle: "Tailor the experience to your daily routine."
            ) {
                MyGoalSelectionView()
            }
            .tag(1)
            
            // Slide 2: Ready / Sync
            OnboardingSlideLayout(
                cardTitle: "Summary",
                narrativeTitle: "You're All Set!",
                narrativeSubtitle: "Let's begin your first session."
            ) {
                MySummaryCardView()
            }
            .tag(2)
        } bottomActions: {
            OnboardingPrimaryButton(
                title: coordinator.isLastStep ? "Get Started" : "Continue",
                backgroundColor: .primary
            ) {
                if coordinator.isLastStep {
                    hasCompletedOnboarding = true
                    dismiss()
                } else {
                    withAnimation {
                        coordinator.next()
                    }
                }
            }
            
            if !coordinator.isLastStep {
                OnboardingSecondaryButton {
                    withAnimation {
                        coordinator.next()
                    }
                }
            }
        }
    }
}
```

#### 8. Developer Debug Section (`DebugSectionView` / `DebugNavigationView`)

GAL provides a drop-in developer & QA debug suite that standardizes review prompt resetting, paywall entitlement toggling, Light/Dark appearance mode simulation, RevenueCat dynamic offering previewing, and onboarding reset/relaunching.

Using `DebugSectionView` automatically handles the `#if DEBUG` condition internally, producing `EmptyView()` in Release builds with zero extra code:

```swift
// No #if DEBUG needed in your SettingsView!
DebugSectionView(
    unlimitedAccess: $hasPurchasedUnlimitedAccess, // Optional: binds directly to your Pro/Unlimited state
    tierName: "Unlimited Access",                  // Optional: custom tier name
    paywallAction: { showPaywall = true },         // Optional: trigger paywall sheet
    loadOfferings: {                               // Optional: fetch offerings dynamically
        let offerings = await PurchaseManager.shared.fetchAvailableOfferings()
        return offerings.map { $0.identifier }
    },
    onSelectOffering: { offeringId in              // Optional: test a specific offering's paywall
        selectedOffering = offeringId
        showPaywall = true
    },
    onboardingView: {                              // Optional: omit if your app has no onboarding!
        OnboardingView()
    },
    onResetOverrides: {                            // Optional: reset custom app-specific debug flags
        hasDismissedBanner = false
        simulateZeroData = false
    }
) {
    // App-specific debug tools (mock data, sister apps, danger zone)
    Section("Danger Zone") {
        Button("Clear All Data", role: .destructive) {
            clearDatabase()
        }
    }
}
```

#### 10. Automated App Store Screenshots & Marketing Presets

GraceAppsLibrary provides an end-to-end framework and CLI runner for generating localized, marketing-ready App Store screenshots across iPhone and iPad with zero blank splash screens and automatic Pro entitlement overrides.

##### The 5–6 Screen Framework
Every App Store screenshot set across Grace Apps collects 5–6 screens showing:
1. **Your app’s main benefit** — The primary transformation or core value hook that solves the user's immediate problem.
2. **Its most important feature** — The flagship interaction or primary tool the user interacts with daily.
3. **A second useful feature** — A supporting capability that deepens engagement (e.g. search, notes, history, or recipe logs).
4. **A realistic example of the result users get** — Proof of progress and consistency over time (e.g. monthly consistency calendar, milestone celebration, earned badge collection).
5. **Customization or another differentiator** — Personalization options, custom goals, pro perks, or unique controls that separate the app from generic alternatives.

See [Skills/SCREENSHOTS.md](Skills/SCREENSHOTS.md) for the complete screenshot design playbook and caption guidelines.

##### Architecture & Components
- **`ScreenshotPresetProvider`**: Protocol defining your app's marketing presets (slot label, headline, suggested filename, system icon, CLI token parser).
- **`ScreenshotLanguage`**: Multi-language registry (`en`, `zh`, `de`, `es`, `ja`, `fr`, `auto`) resolving Apple locale codes and folder naming conventions.
- **`ScreenshotEngine<Preset>`**: `@MainActor` base manager that parses launch arguments (`-SCREENSHOT_PRESET`, `-SCREENSHOT_LANG`), manages active presets, forces Pro entitlement override, and coordinates mock data seeding.
- **`DebugScreenshotSection`**: SwiftUI view section for previewing and testing presets inside the app.
- **`DebugMenuView` Integration**: Directly embeds screenshot preset testing as a first-class section inside `DebugMenuView`.
- **`scripts/capture_screenshots.sh`**: Universal simulator capture runner with bundle ID auto-discovery, simulator focus, cold-launch process cooldown, and Vision frame-variance splash-screen verification.

##### Step-by-Step Implementation

###### Step 1: Define Presets (or Use Built-in `StandardScreenshotPreset`)
If your app follows standard App Store slots (Benefit, Top Feature, Secondary Feature, Results Calendar, Milestone Celebration, Customization, Settings), simply use `StandardScreenshotPreset`.

If you prefer custom slots, conform an enum to `ScreenshotPresetProvider`:

```swift
import GraceAppsLibrary

public enum AppScreenshotPreset: String, CaseIterable, ScreenshotPresetProvider {
    case benefit = "1"
    case feature = "2"
    case historyNotes = "3"
    case calendar = "4"
    case celebration = "4b"
    case customGoals = "5"
    case settingsOverview = "5b"

    public var id: String { rawValue }

    // Optional: Auto-navigates root tabs on launch
    public var targetTabIndex: Int? {
        switch self {
        case .benefit: return 0
        case .feature, .calendar, .celebration: return 1
        case .customGoals, .settingsOverview: return 2
        case .historyNotes: return 3
        }
    }

    public var slotLabel: String {
        switch self {
        case .benefit: return "Slot #1 • Main Benefit"
        case .feature: return "Slot #2 • Top Feature"
        case .historyNotes: return "Slot #3 • Second Feature"
        case .calendar: return "Slot #4A • Consistency Calendar"
        case .celebration: return "Slot #4B • Streak Celebration"
        case .customGoals: return "Slot #5A • Differentiator (Custom Goals)"
        case .settingsOverview: return "Slot #5B • Settings Overview"
        }
    }

    public var title: String {
        switch self {
        case .benefit: return "Active Timer (Goal Met)"
        case .feature: return "Dashboard & Weekly Trends"
        case .historyNotes: return "Reading History & Notes"
        case .calendar: return "Monthly Calendar & Badges"
        case .celebration: return "30-Day Milestone Celebration"
        case .customGoals: return "Custom Daily Goals Screen"
        case .settingsOverview: return "Settings & Pro Overview"
        }
    }

    public var suggestedFilename: String {
        switch self {
        case .benefit: return "01 - Reading Timer Goal Met"
        case .feature: return "02 - Reading Streak and Weekly Chart"
        case .historyNotes: return "03 - Reading History and Book Notes"
        case .calendar: return "04A - Monthly Calendar and Milestones"
        case .celebration: return "04B - 30-Day Streak Celebration"
        case .customGoals: return "05A - Custom Daily Reading Goals"
        case .settingsOverview: return "05B - Settings and Pro Overview"
        }
    }

    public var systemImage: String {
        switch self {
        case .benefit: return "timer"
        case .feature: return "chart.bar.xaxis"
        case .historyNotes: return "note.text"
        case .calendar: return "calendar"
        case .celebration: return "trophy.fill"
        case .customGoals: return "slider.horizontal.3"
        case .settingsOverview: return "gearshape.fill"
        }
    }

    public static func from(token: String) -> AppScreenshotPreset? {
        let normalized = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "1", "timer", "benefit": return .benefit
        case "2", "dashboard", "feature": return .feature
        case "3", "history", "notes": return .historyNotes
        case "4", "4a", "calendar": return .calendar
        case "4b", "celebration": return .celebration
        case "5", "5a", "goals": return .customGoals
        case "5b", "settings": return .settingsOverview
        default: return nil
        }
    }
}
```

###### Step 2: Initialize `ScreenshotEngine` (Subclass or Closure Delegation)
You can instantiate `ScreenshotEngine` directly and attach closures:

```swift
@MainActor
final class AppScreenshotManager {
    static let shared = ScreenshotEngine<StandardScreenshotPreset>()

    static func configure() {
        shared.onApply = { preset in
            // Safety guard: ensure CoreData is running in-memory
            guard ScreenshotEngine.isInMemoryStore(context: PersistenceController.shared.container.viewContext) else { return }
            seedMockData(for: preset, language: shared.effectiveLanguage)
        }
    }
}
```

Or subclass `ScreenshotEngine<Preset>` if you prefer overriding `apply(preset:)`:

```swift
@MainActor
final class AppScreenshotManager: ScreenshotEngine<AppScreenshotPreset> {
    static let shared = AppScreenshotManager()

    @Published var shouldNavigateToDailyGoal = false
    @Published var shouldSelectTodayInCalendar = false

    override func apply(preset: AppScreenshotPreset) {
        super.apply(preset: preset) // Automatically forces Pro entitlement override

        let lang = effectiveLanguage
        
        // 1. Seed milestones/flags BEFORE seeding CoreData items
        UserDefaults.standard.set(["streak-7", "streak-30"], forKey: "unlocked_milestones")

        // 2. Seed mock CoreData items
        seedMockData(for: preset, language: lang)

        // 3. Coordinate navigation
        switch preset {
        case .benefit:
            NotificationCenter.default.post(name: .switchToTab, object: 0)
        case .feature:
            NotificationCenter.default.post(name: .switchToTab, object: 1)
        case .calendar:
            shouldSelectTodayInCalendar = true
            NotificationCenter.default.post(name: .switchToTab, object: 1)
        case .celebration:
            NotificationCenter.default.post(name: .switchToTab, object: 1)
            triggerCelebrationModal()
        case .customGoals:
            shouldNavigateToDailyGoal = true
            NotificationCenter.default.post(name: .switchToTab, object: 2)
        case .settingsOverview:
            shouldNavigateToDailyGoal = false
            NotificationCenter.default.post(name: .switchToTab, object: 2)
        }
    }

    func handleAppLaunch(selectedTab: Binding<Int>) {
        guard let preset = activePreset else { return }
        switch preset {
        case .benefit: selectedTab.wrappedValue = 0
        case .feature, .calendar, .celebration: selectedTab.wrappedValue = 1
        case .customGoals, .settingsOverview: selectedTab.wrappedValue = 2
        case .historyNotes: selectedTab.wrappedValue = 3
        }
        apply(preset: preset)
    }
}
```

###### Step 3: Embed Directly in `DebugMenuView`
`DebugMenuView` includes built-in support for `screenshotEngine`. Simply pass your engine to the initializer:

```swift
DebugMenuView(
    entitlementOverride: $debugOverride,
    screenshotEngine: AppScreenshotManager.shared,
    onApplyScreenshotPreset: { preset in
        AppScreenshotManager.shared.apply(preset: preset)
    },
    onResetScreenshotPreset: {
        AppScreenshotManager.shared.reset()
    }
)
```

Alternatively, you can embed [`DebugScreenshotSection`](file:///Users/lehuang/Projects/apps/GraceAppsLibrary/Sources/GraceAppsLibrary/Views/Debug/DebugScreenshotSection.swift) standalone in any custom debug view:

```swift
DebugScreenshotSection(
    engine: AppScreenshotManager.shared,
    onApplyPreset: { preset in
        AppScreenshotManager.shared.apply(preset: preset)
    }
)
```

###### Step 4: Handle App Cold-Launch
In your root `ContentView` or App struct, check for launch arguments when launched by the CLI runner:

```swift
#if DEBUG
.onAppear {
    AppScreenshotManager.shared.handleAppLaunch(selectedTab: $selectedTab)
}
#endif
```

###### Step 5: Automate Simulator Captures via CLI
Run the universal runner script from `GraceAppsLibrary/scripts/capture_screenshots.sh`:

```bash
# Capture iPhone only (automatically detects supported languages from .app bundle)
./scripts/capture_screenshots.sh \
  --bundle "com.deelightfullabs.ReadingLog" \
  --presets "1|01 - Timer.png,2|02 - Dashboard.png,4A|04A - Calendar.png,4B|04B - Celebration.png,5A|05A - Goals.png,5B|05B - Settings.png" \
  --iphone-only

# Capture specific language(s)
./scripts/capture_screenshots.sh \
  --bundle "com.deelightfullabs.ReadingLog" \
  --lang zh,en
```

###### Delegating from Client Apps
In your app's repository, create a lightweight runner script (e.g. `Scripts/capture_screenshots.sh`) that resolves GAL from SPM checkouts or local checkouts:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_NAME="$(basename "${ROOT_DIR}")"

# Find GAL runner in DerivedData SPM checkouts or sibling checkout
RUNNER=$(find ~/Library/Developer/Xcode/DerivedData -maxdepth 7 -path "*/SourcePackages/checkouts/GraceAppsLibrary/scripts/capture_screenshots.sh" 2>/dev/null | head -n 1 || true)
if [[ -z "${RUNNER}" && -f "${ROOT_DIR}/../GraceAppsLibrary/scripts/capture_screenshots.sh" ]]; then
  RUNNER="${ROOT_DIR}/../GraceAppsLibrary/scripts/capture_screenshots.sh"
fi

exec bash "${RUNNER}" \
  --bundle "com.yourcompany.app" \
  --output-dir "${ROOT_DIR}/Screenshots/Raw" \
  "$@"
```

## Development

### Translation Consistency
This library supports multiple languages. To ensure all keys are synchronized across all `.lproj` folders, run the provided check script:

```bash
python3 scripts/check_translations.py
```

This check is also automatically performed when running `scripts/build.sh`.

### Versioning
See [VERSIONING.md](VERSIONING.md) for semantic versioning rules and release conventions.

