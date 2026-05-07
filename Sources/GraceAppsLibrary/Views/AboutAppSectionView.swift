import SwiftUI

/// A reusable Settings `Section` that displays app version info, a "What's New" button,
/// and links to rate or share the app on the App Store.
///
/// - Requires: The host app's `Bundle` must have `CFBundleDisplayName` or `CFBundleName`
///   set, and `CFBundleShortVersionString` / `CFBundleVersion` for the version display.
public struct AboutAppSectionView: View {
    let appStoreId: String?
    let releaseNotes: [ReleaseNote]

    /// - Parameters:
    ///   - appStoreId: The numeric App Store ID string (e.g. `"id1234567890"` or just `"1234567890"`).
    ///   - releaseNotes: The array of `ReleaseNote` objects to show in the "What's New" sheet.
    public init(appStoreId: String? = nil, releaseNotes: [ReleaseNote] = []) {
        self.appStoreId = appStoreId
        self.releaseNotes = releaseNotes
    }

    // MARK: - Computed helpers

    var normalizedAppStoreId: String? {
        guard let appStoreId else { return nil }
        return appStoreId.hasPrefix("id") ? appStoreId : "id\(appStoreId)"
    }

    var reviewURL: URL? {
        guard let normalizedAppStoreId else { return nil }
        return URL(string: "https://apps.apple.com/app/\(normalizedAppStoreId)?action=write-review")
    }

    var shareURL: URL? {
        guard let normalizedAppStoreId else { return nil }
        return URL(string: "https://apps.apple.com/app/\(normalizedAppStoreId)")
    }

    var appVersion: String {
        let bundle = Bundle.main
        let release = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build   = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "?"
#if DEBUG
        return "Debug - \(release) (\(build))"
#else
        return "Release - \(release) (\(build))"
#endif
    }

    var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? NSLocalizedString(Constants.StringKeys.aboutAppFallback, bundle: .module, comment: "")
    }

    // MARK: - Body

    public var body: some View {
        Section(header: Text(String(format: NSLocalizedString(Constants.StringKeys.aboutSectionTitle, bundle: .module, comment: ""), appName))) {
            // Version row
            HStack {
                Label(NSLocalizedString(Constants.StringKeys.aboutVersion, bundle: .module, comment: ""), systemImage: "info.circle")
                Spacer()
                Text(appVersion)
                    .foregroundColor(.secondary)
            }

            // What's New
            if !releaseNotes.isEmpty {
                WhatIsNewView(releaseNotes: releaseNotes)
            }

            // Rate This App
            if let url = reviewURL {
                Link(destination: url) {
                    Label(NSLocalizedString(Constants.StringKeys.aboutRateThisApp, bundle: .module, comment: ""), systemImage: "star")
                }
            }

            // Share This App
            if let url = shareURL {
                if #available(iOS 16, *) {
                    ShareLink(item: url) {
                        Label(NSLocalizedString(Constants.StringKeys.aboutShareThisApp, bundle: .module, comment: ""), systemImage: "square.and.arrow.up")
                    }
                } else {
                    Link(destination: url) {
                        Label(NSLocalizedString(Constants.StringKeys.aboutShareThisApp, bundle: .module, comment: ""), systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}

#Preview("With ID") {
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

#Preview("Without ID") {
    NavigationView {
        Form {
            AboutAppSectionView(
                releaseNotes: [
                    ReleaseNote(version: "1.0.0", notes: ["Initial release."])
                ]
            )
        }
        .navigationTitle("Settings")
    }
}
