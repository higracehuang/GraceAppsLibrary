import XCTest
import CloudKit
@testable import GraceAppsLibrary

@MainActor
final class CloudKitSyncManagerTests: XCTestCase {

    func testFriendlyErrorMessages() {
        let manager = CloudKitSyncManager.shared

        let quotaError = CKError(.quotaExceeded)
        XCTAssertTrue(manager.friendlyErrorMessage(for: quotaError).lowercased().contains("storage"))

        let authError = CKError(.notAuthenticated)
        XCTAssertTrue(manager.friendlyErrorMessage(for: authError).lowercased().contains("signed in"))

        let networkError = CKError(.networkUnavailable)
        XCTAssertTrue(manager.friendlyErrorMessage(for: networkError).lowercased().contains("offline"))

        let rateLimitError = CKError(.requestRateLimited)
        XCTAssertTrue(manager.friendlyErrorMessage(for: rateLimitError).lowercased().contains("rate limit"))

        let zoneError = CKError(.zoneNotFound)
        XCTAssertTrue(manager.friendlyErrorMessage(for: zoneError).lowercased().contains("reset"))
    }

    func testLastSyncFormatting() {
        let manager = CloudKitSyncManager.shared

        manager.lastSuccessfulSync = nil
        XCTAssertEqual(manager.lastSyncFormatted, "Never")

        manager.lastSuccessfulSync = Date()
        XCTAssertEqual(manager.lastSyncFormatted, "Just now")

        manager.lastSuccessfulSync = Date().addingTimeInterval(-65)
        XCTAssertEqual(manager.lastSyncFormatted, "1 min ago")

        manager.lastSuccessfulSync = Date().addingTimeInterval(-300)
        XCTAssertEqual(manager.lastSyncFormatted, "5 mins ago")
    }

    func testConfigureSetsContainerWithoutCrashing() {
        let manager = CloudKitSyncManager.shared
        var manualSyncCalled = false
        manager.configure(containerIdentifier: "iCloud.com.deelightfullabs.RowCounter") {
            manualSyncCalled = true
        }
        XCTAssertFalse(manualSyncCalled)
    }
}
