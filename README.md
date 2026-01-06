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
To display release notes (typically in a `.sheet`), you can use the `ReleaseNotesManager` to handle the conditional display logic:

```swift
struct MyContentView: View {
    @State private var showReleaseNotes = false
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
        .onAppear {
            if ReleaseNotesManager.shared.shouldShow(releaseNotes: releaseNotes) {
                showReleaseNotes = true
            }
        }
        .sheet(isPresented: $showReleaseNotes) {
            ReleaseNotesView(
                releaseNotes: releaseNotes,
                onDismiss: {
                    ReleaseNotesManager.shared.markCurrentVersionAsViewed()
                    showReleaseNotes = false
                }
            )
        }
    }
}
```
