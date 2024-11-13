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

To display all apps in a list:
```swift
GraceAppsView()
```

or 

```swift
GraceAppsView(excluding: "id1633932632")
```

To display a request for feedback:

```swift
FeedbackToGraceView()
```
