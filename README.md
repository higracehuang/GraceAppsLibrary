# GraceAppsLibrary

A Swift package that provides information about Grace Apps' iOS applications, including names, descriptions, and App Store links. Supports multiple languages including English, Japanese, Simplified Chinese, and German.

## Features

- Get information about all Grace Apps
- Localized app names and descriptions in multiple languages
- App Store links
- Option to exclude specific apps from the list
- iOS 14+ support

## Installation

1. Add this package to your Xcode project using Swift Package Manager.
1. Import the package in your Swift file:

```swift
import GraceAppsLibrary
```
## Usage

### Methods
Use the `getAllApps` function to get the list of apps:

```swift
let apps = GraceAppsLibrary.getAllApps()
```
 
or exclude a specific app:

```swift
let apps = GraceAppsLibrary.getAllApps(excluding: "id1633932632")
```

In the UI, while you loop through the apps, you can use the `localizedName` and `localizedDescription` properties to get the localized name and description for the current locale:

```swift
let name = app.localizedName
let description = app.localizedDescription
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
.graceReleaseNotes(releaseNotes: [
    ReleaseNote(
        version: "2.0.0",
        notes: ["New features!", "Bug fixes."],
        heroImageName: "AppIcon"
    )
])
```

> [!TIP]
> This modifier handles both "Done" button and swipe-to-dismiss, ensuring users don't see the same notes twice.
