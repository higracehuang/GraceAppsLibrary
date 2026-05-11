# GraceAppsLibrary

A Swift package that provides information about Grace Apps' iOS applications, including names, descriptions, and App Store links. Supports multiple languages including English, Japanese, Simplified Chinese, and German.

## Features

- Get information about all Grace Apps
- Localized app names and descriptions in multiple languages
- App Store links
- Option to exclude specific apps from the list
- iOS 14+ support
- Built-in views for displaying apps, feedback, release notes, FAQs, and emoji input

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
    isPaidUser: purchaseStore.isPro, // Hides CTA if true
    tierName: "Unlimited Access",    // Custom name for premium tier
    paywallAction: {                // Action for the upgrade button
        showPaywall = true 
    }
)
```

> [!TIP]
> The CTA button will only automatically appear for the **first release note in the list that contains a paid feature** (`isPaidFeature: true`), ensuring a clean UI.

> [!TIP]
> This modifier handles both "Done" button and swipe-to-dismiss, ensuring users don't see the same notes twice.

#### 3. Display "What's New" in Settings
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

#### 4. Emoji Input Support
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

#### 5. Show FAQs
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

#### 6. About App Section
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

#### 7. Language Setting Link
Use `LanguageSettingLinkView` to provide a direct link to the app's settings in the System Settings app, allowing users to quickly change the app's language. It displays the current preferred language as a badge (iOS 15+) or trailing text (iOS 14).

```swift
LanguageSettingLinkView()
```

#### 8. Help & Support Section
Use `HelpSupportSectionView` to provide a unified help section in your Settings screen. It can optionally show FAQs, a link to "Sources & References", and a feedback link.

```swift
HelpSupportSectionView(
    faqSections: myFAQSections, // Optional: Shows FAQNavigationView if provided
    sourceSections: mySourceSections, // Optional: Shows NavigationLink to SourcesView if provided
    sourceDisclaimer: "Optional disclaimer text", // Optional: Used in SourcesView
    showFeedback: true // Optional: Defaults to true, shows FeedbackToGraceNavigationView
)
```

#### 9. About Developer Section
Use `AboutDeveloperSectionView` to add a ready-made "About the App Developer" section to your Settings screen. It provides a navigation link to the developer's other apps.

```swift
AboutDeveloperSectionView(
    excludingAppId: "id1234567890" // Optional: Excludes current app from the list
)
```

## Development

### Translation Consistency
This library supports multiple languages. To ensure all keys are synchronized across all `.lproj` folders, run the provided check script:

```bash
python3 scripts/check_translations.py
```

This check is also automatically performed when running `scripts/build.sh`.
