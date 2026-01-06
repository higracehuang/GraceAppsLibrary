import XCTest
@testable import GraceAppsLibrary

final class ReleaseNotesTests: XCTestCase {
    var userDefaults: UserDefaults!
    var manager: ReleaseNotesManager!
    let suiteName = "ReleaseNotesTests"
    
    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
        manager = ReleaseNotesManager(userDefaults: userDefaults)
    }
    
    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }
    
    func testShouldShowReleaseNotes() {
        let releaseNotes = [
            ReleaseNote(version: "1.0.0", notes: ["Initial release"]),
            ReleaseNote(version: "2.0.0", notes: ["Big update"])
        ]
        
        // Test with version that has release notes
        XCTAssertTrue(manager.shouldShowReleaseNotes(currentVersion: "2.0.0", releaseNotes: releaseNotes))
        
        // Test with version that DOES NOT have release notes
        XCTAssertFalse(manager.shouldShowReleaseNotes(currentVersion: "1.5.0", releaseNotes: releaseNotes))
        
        // Test after marking as viewed
        manager.markAsViewed(version: "2.0.0")
        XCTAssertFalse(manager.shouldShowReleaseNotes(currentVersion: "2.0.0", releaseNotes: releaseNotes))
        
        // Test after update to new version
        XCTAssertTrue(manager.shouldShowReleaseNotes(currentVersion: "3.0.0", releaseNotes: [
            ReleaseNote(version: "3.0.0", notes: ["Newer update"])
        ]))
    }
    
    func testPersistence() {
        let version = "2.1.0"
        manager.markAsViewed(version: version)
        
        // Create a new manager with same user defaults to test persistence
        let newManager = ReleaseNotesManager(userDefaults: userDefaults)
        XCTAssertFalse(newManager.shouldShowReleaseNotes(currentVersion: version, releaseNotes: [
            ReleaseNote(version: version, notes: ["Test"])
        ]))
    }
}
