import Foundation

/// Helper utility for managing persistence and version-based onboarding presentation logic.
public struct OnboardingManager {
    public static let defaultStorageKey = "gal_has_completed_onboarding"
    public static let defaultVersionKey = "gal_last_completed_onboarding_version"
    
    /// Checks whether onboarding has been marked as completed.
    public static func hasCompletedOnboarding(
        key: String = defaultStorageKey,
        userDefaults: UserDefaults = .standard
    ) -> Bool {
        userDefaults.bool(forKey: key)
    }
    
    /// Marks onboarding as completed or incomplete.
    public static func setCompletedOnboarding(
        _ completed: Bool,
        key: String = defaultStorageKey,
        userDefaults: UserDefaults = .standard
    ) {
        userDefaults.set(completed, forKey: key)
    }
    
    /// Checks whether onboarding should be shown for a specific version.
    /// If the recorded completed version is lower than `targetVersion` or empty, returns `true`.
    public static func shouldShowOnboarding(
        forVersion targetVersion: String,
        versionKey: String = defaultVersionKey,
        userDefaults: UserDefaults = .standard
    ) -> Bool {
        guard let lastVersion = userDefaults.string(forKey: versionKey), !lastVersion.isEmpty else {
            return true
        }
        return lastVersion.compare(targetVersion, options: .numeric) == .orderedAscending
    }
    
    /// Records that onboarding was completed for a given version.
    public static func recordOnboardingCompleted(
        forVersion version: String,
        versionKey: String = defaultVersionKey,
        completionKey: String = defaultStorageKey,
        userDefaults: UserDefaults = .standard
    ) {
        userDefaults.set(version, forKey: versionKey)
        userDefaults.set(true, forKey: completionKey)
    }
    
    /// Resets all onboarding completion status for testing or debug menus.
    public static func reset(
        completionKey: String = defaultStorageKey,
        versionKey: String = defaultVersionKey,
        userDefaults: UserDefaults = .standard
    ) {
        userDefaults.removeObject(forKey: completionKey)
        userDefaults.removeObject(forKey: versionKey)
    }
}
