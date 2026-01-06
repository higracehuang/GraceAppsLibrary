import Foundation

public class ReleaseNotesManager {
    public static let shared = ReleaseNotesManager()
    
    private let lastViewedVersionKey = "GraceAppsLibrary_LastViewedReleaseNotesVersion"
    private let userDefaults: UserDefaults
    
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    /// The current version of the app as defined in the main bundle's Info.plist
    public var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    /// Checks if the release notes should be shown for the current app version
    /// - Parameter releaseNotes: The list of available release notes
    /// - Returns: True if the current version's release notes haven't been seen yet
    public func shouldShow(releaseNotes: [ReleaseNote]) -> Bool {
        shouldShowReleaseNotes(currentVersion: currentVersion, releaseNotes: releaseNotes)
    }
    
    /// Marks the current app version as viewed
    public func markCurrentVersionAsViewed() {
        markAsViewed(version: currentVersion)
    }
    
    /// Checks if the release notes should be shown for the current version
    /// - Parameters:
    ///   - currentVersion: The current version of the app (e.g., from Bundle)
    ///   - releaseNotes: The list of available release notes
    /// - Returns: True if the current version's release notes haven't been seen yet
    public func shouldShowReleaseNotes(currentVersion: String, releaseNotes: [ReleaseNote]) -> Bool {
        // If there are no release notes, don't show anything
        guard !releaseNotes.isEmpty else { return false }
        
        // Find if there's a release note for the current version
        // (Assuming we only show the sheet if there's a note for the CURRENT version)
        guard releaseNotes.contains(where: { $0.version == currentVersion }) else {
            return false
        }
        
        let lastViewed = userDefaults.string(forKey: lastViewedVersionKey)
        
        // If last viewed is different from current, it's a new release
        return lastViewed != currentVersion
    }
    
    /// Marks the current version as viewed
    /// - Parameter version: The version to mark as viewed
    public func markAsViewed(version: String) {
        userDefaults.set(version, forKey: lastViewedVersionKey)
    }
}
