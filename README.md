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

### Views

You can use the views directly in your SwiftUI code:

#### GraceAppsView
To display all apps in a list:
```swift
GraceAppsView()
```

or 

```swift
GraceAppsView(excluding: "id1633932632")
```

#### FeedbackToGraceView
To display a request for feedback:

```swift
FeedbackToGraceView()
```

#### ReleaseNotesView
To display release notes (typically in a `.sheet`), you can use the `graceReleaseNotes` view modifier for a robust and automatic integration:

```swift
struct MyContentView: View {
    private let releaseNotes = [
        ReleaseNote(
            version: "2.0.0",
            notes: [
                "Added support for multiple bullet points in release notes.",
                "Implemented optional hero images for each release.",
            ],
            heroImageName: "FastingLadyIcon"
        )
    ]

    var body: some View {
        VStack {
            // Your app content
        }
        .graceReleaseNotes(releaseNotes: releaseNotes)
    }
}
```

This modifier automatically:
1. Checks if release notes should be shown for the current app version.
2. Displays the `ReleaseNotesView` in a sheet if needed.
3. Marks the current version as viewed when the sheet is dismissed (handles both "Done" button and swipe-to-dismiss).
