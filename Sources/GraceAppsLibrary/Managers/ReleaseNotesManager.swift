import Foundation

public class ReleaseNotesManager {
    public static let shared = ReleaseNotesManager()
    
    private let lastViewedVersionKey = "GraceAppsLibrary_LastViewedReleaseNotesVersion"
    private let userDefaults: UserDefaults
    
    /// Tracks if release notes were presented during the current active app session.
    @MainActor public static var hasShownReleaseNotesThisSession: Bool = false
    
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    /// The current version of the app as defined in the main bundle's Info.plist
    public var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    /// The last viewed release notes version stored in UserDefaults, if any.
    public var lastViewedVersion: String? {
        userDefaults.string(forKey: lastViewedVersionKey)
    }
    
    /// Whether the app is currently running as a fresh installation (no prior version viewed).
    public var isFirstInstall: Bool {
        lastViewedVersion == nil
    }
    
    /// Checks if the release notes should be shown for the current app version
    /// - Parameters:
    ///   - releaseNotes: The list of available release notes
    ///   - suppressOnFirstInstall: If true (default), suppresses release notes for new user fresh installs
    /// - Returns: True if the current version's release notes should be shown (e.g. on app upgrade)
    public func shouldShow(releaseNotes: [ReleaseNote], suppressOnFirstInstall: Bool = true) -> Bool {
        shouldShowReleaseNotes(
            currentVersion: currentVersion,
            releaseNotes: releaseNotes,
            suppressOnFirstInstall: suppressOnFirstInstall
        )
    }
    
    /// Marks the current app version as viewed
    public func markCurrentVersionAsViewed() {
        markAsViewed(version: currentVersion)
    }
    
    /// Checks if the release notes should be shown for the current version
    /// - Parameters:
    ///   - currentVersion: The current version of the app (e.g., from Bundle)
    ///   - releaseNotes: The list of available release notes
    ///   - suppressOnFirstInstall: If true (default), suppresses release notes on fresh installations
    /// - Returns: True if the current version's release notes haven't been seen yet and it's an upgrade from a previous version
    public func shouldShowReleaseNotes(
        currentVersion: String,
        releaseNotes: [ReleaseNote],
        suppressOnFirstInstall: Bool = true
    ) -> Bool {
        GraceLogger.info("Checking if should show release notes for version: \(currentVersion)")
        
        // If there are no release notes, don't show anything
        guard !releaseNotes.isEmpty else {
            GraceLogger.info("No release notes available.")
            return false
        }
        
        GraceLogger.info("Available release notes versions: \(releaseNotes.map { $0.version })")
        
        // Find if there's a release note for the current version
        // (Assuming we only show the sheet if there's a note for the CURRENT version)
        guard releaseNotes.contains(where: { $0.version == currentVersion }) else {
            GraceLogger.info("No release note found for current version.")
            return false
        }
        
        guard let lastViewed = userDefaults.string(forKey: lastViewedVersionKey) else {
            if suppressOnFirstInstall {
                GraceLogger.info("Fresh install detected (no prior version viewed). Recording current version \(currentVersion) as viewed and suppressing release notes for onboarding.", category: .app)
                markAsViewed(version: currentVersion)
                return false
            } else {
                GraceLogger.info("Fresh install detected and suppressOnFirstInstall is false. Showing release notes for \(currentVersion).")
                return true
            }
        }
        
        GraceLogger.info("Last viewed version: \(lastViewed)")
        
        // If last viewed is different from current, it's an app upgrade
        let isUpgrade = lastViewed != currentVersion
        GraceLogger.info("Should show release notes: \(isUpgrade)")
        return isUpgrade
    }
    
    /// Marks the current version as viewed
    /// - Parameter version: The version to mark as viewed
    public func markAsViewed(version: String) {
        GraceLogger.info("Marking version \(version) as viewed")
        userDefaults.set(version, forKey: lastViewedVersionKey)
    }
    
    /// Resets the release notes viewed state in UserDefaults (for debug / testing).
    public func resetReleaseNotesState() {
        GraceLogger.info("Resetting release notes state.", category: .debug)
        userDefaults.removeObject(forKey: lastViewedVersionKey)
    }
    
    /// Static helper to reset release notes state in standard UserDefaults.
    public static func debugResetReleaseNotesState(userDefaults: UserDefaults = .standard) {
        userDefaults.removeObject(forKey: "GraceAppsLibrary_LastViewedReleaseNotesVersion")
    }
}
