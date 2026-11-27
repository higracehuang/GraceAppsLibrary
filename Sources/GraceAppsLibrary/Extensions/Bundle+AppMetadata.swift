import Foundation
import GraceAppsLibraryCore

extension Bundle {
    /// The bundle containing GraceAppsLibrary resources.
    public static var graceAppsLibrary: Bundle {
        Bundle.module
    }

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

    /// Returns `"Debug"` in debug builds unless screenshot capture is active; returns `""` during screenshots or in release builds.
    public var buildType: String {
        resolvedBuildType()
    }

    /// Returns `"Debug"` in debug builds unless `arguments`/`environment` indicate an active screenshot capture run.
    public func resolvedBuildType(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String {
        #if DEBUG
        return GraceLaunchFlags.isScreenshotCaptureActive(arguments: arguments, environment: environment) ? "" : "Debug"
        #else
        return ""
        #endif
    }

    /// Returns a formatted display version string for settings/about screens.
    public var displayVersionString: String {
        resolvedDisplayVersionString()
    }

    /// Returns a formatted display version string, omitting `"Debug - "` during screenshots or in release builds.
    public func resolvedDisplayVersionString(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String {
        let version = "\(releaseVersionNumber) (\(buildVersionNumber))"
        let label = resolvedBuildType(arguments: arguments, environment: environment)
        return label.isEmpty ? version : "\(label) - \(version)"
    }
}
