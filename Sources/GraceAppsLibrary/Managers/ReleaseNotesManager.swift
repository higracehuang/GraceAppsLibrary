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
        print("[ReleaseNotesManager] Checking if should show release notes for version: \(currentVersion)")
        
        // If there are no release notes, don't show anything
        guard !releaseNotes.isEmpty else {
            print("[ReleaseNotesManager] No release notes available.")
            return false
        }
        
        print("[ReleaseNotesManager] Available release notes versions: \(releaseNotes.map { $0.version })")
        
        // Find if there's a release note for the current version
        // (Assuming we only show the sheet if there's a note for the CURRENT version)
        guard releaseNotes.contains(where: { $0.version == currentVersion }) else {
            print("[ReleaseNotesManager] No release note found for current version.")
            return false
        }
        
        let lastViewed = userDefaults.string(forKey: lastViewedVersionKey)
        print("[ReleaseNotesManager] Last viewed version: \(lastViewed ?? "none")")
        
        // If last viewed is different from current, it's a new release
        let shouldShow = lastViewed != currentVersion
        print("[ReleaseNotesManager] Should show release notes: \(shouldShow)")
        return shouldShow
    }
    
    /// Marks the current version as viewed
    /// - Parameter version: The version to mark as viewed
    public func markAsViewed(version: String) {
        print("[ReleaseNotesManager] Marking version \(version) as viewed")
        userDefaults.set(version, forKey: lastViewedVersionKey)
    }
}

// MARK: - SwiftUI Integration
import SwiftUI

public extension View {
    /// Automatically shows release notes if they haven't been viewed for the current version
    /// - Parameter releaseNotes: The list of available release notes
    /// - Returns: A view that shows release notes in a sheet if needed
    func graceReleaseNotes(releaseNotes: [ReleaseNote]) -> some View {
        self.modifier(GraceReleaseNotesModifier(releaseNotes: releaseNotes))
    }
}

struct GraceReleaseNotesModifier: ViewModifier {
    let releaseNotes: [ReleaseNote]
    @State private var isPresented = false
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                if ReleaseNotesManager.shared.shouldShow(releaseNotes: releaseNotes) {
                    isPresented = true
                }
            }
            .sheet(isPresented: $isPresented, onDismiss: {
                ReleaseNotesManager.shared.markCurrentVersionAsViewed()
            }) {
                ReleaseNotesView(releaseNotes: releaseNotes) {
                    isPresented = false
                    // onDismiss of sheet will call markCurrentVersionAsViewed()
                }
            }
    }
}
