import Foundation

public final class ReleaseNotesManager {
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
    
    /// Checks if the release notes should be shown for the current app version.
    /// - Note: Internal to GraceAppsLibrary. Client views should use `UXFlowOrchestrator.shared.requestActions([UXAction.releaseNotes(...)])`.
    internal func shouldShow(releaseNotes: [ReleaseNote], suppressOnFirstInstall: Bool = true) -> Bool {
        shouldShowReleaseNotes(
            currentVersion: currentVersion,
            releaseNotes: releaseNotes,
            suppressOnFirstInstall: suppressOnFirstInstall
        )
    }
    
    /// Marks the current app version as viewed. Internal to GAL.
    internal func markCurrentVersionAsViewed() {
        markAsViewed(version: currentVersion)
    }
    
    /// Checks if the release notes should be shown for the current version.
    /// - Note: Internal to GraceAppsLibrary.
    internal func shouldShowReleaseNotes(
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
    
    /// Marks the specified version as viewed. Internal to GAL.
    internal func markAsViewed(version: String) {
        GraceLogger.info("Marking version \(version) as viewed")
        userDefaults.set(version, forKey: lastViewedVersionKey)
    }
    
    /// Resets the release notes viewed state in UserDefaults (for debug / testing).
    @MainActor
    public func resetReleaseNotesState() {
        GraceLogger.info("Resetting release notes state.", category: .debug)
        Self.hasShownReleaseNotesThisSession = false
        userDefaults.removeObject(forKey: lastViewedVersionKey)
    }

    /// Seeds a simulated previously viewed version in UserDefaults for testing upgrade flows.
    public func seedLastViewedVersionForTesting(_ version: String?) {
        if let version = version {
            userDefaults.set(version, forKey: lastViewedVersionKey)
        } else {
            userDefaults.removeObject(forKey: lastViewedVersionKey)
        }
    }
    
}
