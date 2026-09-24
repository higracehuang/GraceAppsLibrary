import Foundation

extension Bundle {
    /// Returns the app's display name, falling back to bundle name or "App".
    public var appName: String {
        object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "App"
    }

    /// Returns the release version number string (e.g. "1.0.0").
    public var releaseVersionNumber: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    /// Returns the build version number string (e.g. "42").
    public var buildVersionNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    /// Returns a formatted display version string for settings/about screens.
    public var displayVersionString: String {
        #if DEBUG
        return "Debug - \(releaseVersionNumber) (\(buildVersionNumber))"
        #else
        return "Release - \(releaseVersionNumber) (\(buildVersionNumber))"
        #endif
    }
}
