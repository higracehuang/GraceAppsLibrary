# GraceAppsLibrary

A Swift package that provides information about Grace Apps' iOS applications, including names, descriptions, and App Store links. Supports multiple languages including English, Japanese, Simplified Chinese, and German.

## Features

- Get information about all Grace Apps
- Localized app names and descriptions in multiple languages
- App Store links
- Option to exclude specific apps from the list
- iOS 14+ support
- Built-in views for displaying apps, feedback, release notes, FAQs, and emoji input
- Shared Onboarding framework (`OnboardingContainer`, `OnboardingSlideLayout`, `OnboardingCoordinator`)
- Smart review prompting (`ReviewPromptManager`) with 2-step pre-filter & feedback redirection

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
* **`OnboardingSecondaryButton`**: Secondary text button for "Skip for now" with built-in translations in English, Spanish, Simplified Chinese, German, and Japanese.
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

## Development

### Translation Consistency
This library supports multiple languages. To ensure all keys are synchronized across all `.lproj` folders, run the provided check script:

```bash
python3 scripts/check_translations.py
```

This check is also automatically performed when running `scripts/build.sh`.
