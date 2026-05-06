import SwiftUI

/// A reusable Settings `Section` that displays app version info, a "What's New" button,
/// and links to rate or share the app on the App Store.
///
/// - Requires: The host app's `Bundle` must have `CFBundleDisplayName` or `CFBundleName`
///   set, and `CFBundleShortVersionString` / `CFBundleVersion` for the version display.
public struct AboutAppSectionView: View {
    let appStoreId: String
    let releaseNotes: [ReleaseNote]

    /// - Parameters:
    ///   - appStoreId: The numeric App Store ID string (e.g. `"id1234567890"` or just `"1234567890"`).
    ///   - releaseNotes: The array of `ReleaseNote` objects to show in the "What's New" sheet.
    public init(appStoreId: String, releaseNotes: [ReleaseNote]) {
        self.appStoreId = appStoreId
        self.releaseNotes = releaseNotes
    }

    // MARK: - Computed helpers

    private var normalizedAppStoreId: String {
        appStoreId.hasPrefix("id") ? appStoreId : "id\(appStoreId)"
    }

    private var reviewURL: URL? {
        URL(string: "https://apps.apple.com/app/\(normalizedAppStoreId)?action=write-review")
    }

    private var shareURL: URL? {
        URL(string: "https://apps.apple.com/app/\(normalizedAppStoreId)")
    }

    private var appVersion: String {
        let bundle = Bundle.main
        let release = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build   = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "?"
#if DEBUG
        return "Debug - \(release) (\(build))"
#else
        return "Release - \(release) (\(build))"
#endif
    }

    private var appName: String {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String
            ?? "App"
    }

    // MARK: - Body

    public var body: some View {
        Section(header: Text("About \(appName)")) {
            // Version row
            HStack {
                Label("Version", systemImage: "info.circle")
                Spacer()
                Text(appVersion)
                    .foregroundColor(.secondary)
            }

            // What's New
            WhatIsNewView(releaseNotes: releaseNotes)

            // Rate This App
            if let url = reviewURL {
                Link(destination: url) {
                    Label("Rate This App", systemImage: "star")
                }
            }

            // Share This App
            if #available(iOS 16, *), let url = shareURL {
                ShareLink(item: url) {
                    Label("Share This App", systemImage: "square.and.arrow.up")
                }
            } else if let url = shareURL {
                Link(destination: url) {
                    Label("Share This App", systemImage: "square.and.arrow.up")
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        Form {
            AboutAppSectionView(
                appStoreId: "1234567890",
                releaseNotes: [
                    ReleaseNote(version: "2.0.0", notes: ["New features!", "Bug fixes."]),
                    ReleaseNote(version: "1.0.0", notes: ["Initial release."])
                ]
            )
        }
        .navigationTitle("Settings")
    }
}
