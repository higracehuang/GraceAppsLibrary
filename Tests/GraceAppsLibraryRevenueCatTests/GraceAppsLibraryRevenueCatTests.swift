import XCTest
import GraceAppsLibrary
@testable import GraceAppsLibraryRevenueCat

@MainActor
final class GraceAppsLibraryRevenueCatTests: XCTestCase {
    private var coordinator: UniversalPurchaseCoordinator!
    private let testStorageKey = "test_synced_pro_storage_key"

    override func setUp() async throws {
        try await super.setUp()
        coordinator = UniversalPurchaseCoordinator.shared
        coordinator.syncedStorageKey = testStorageKey
        UserDefaults.standard.removeObject(forKey: testStorageKey)
    }

    override func tearDown() async throws {
        coordinator.debugOverride = .automatic
        coordinator.setStoreStatus(false)
        UserDefaults.standard.removeObject(forKey: testStorageKey)
        try await super.tearDown()
    }

    func testAutomaticModeReflectsStoreStatus() {
        coordinator.debugOverride = .automatic

        coordinator.setStoreStatus(false)
        XCTAssertFalse(coordinator.isPro)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: testStorageKey))

        coordinator.setStoreStatus(true)
        XCTAssertTrue(coordinator.isPro)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: testStorageKey))
    }

    func testForceProOverridesStoreStatus() {
        coordinator.setStoreStatus(false)
        coordinator.debugOverride = .forcePro

        XCTAssertTrue(coordinator.isPro, "Force Pro must override false store status to true")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: testStorageKey))
    }

    func testForceFreeOverridesStoreStatus() {
        coordinator.setStoreStatus(true)
        coordinator.debugOverride = .forceFree

        XCTAssertFalse(coordinator.isPro, "Force Free must override true store status to false")
        XCTAssertFalse(UserDefaults.standard.bool(forKey: testStorageKey))
    }

    func testPacingEngineAutoWiring() {
        coordinator.debugOverride = .automatic
        coordinator.setStoreStatus(false)
        XCTAssertFalse(PaywallPacingEngine.shared.isProUser())
        XCTAssertFalse(AdPacingEngine.shared.isProUser())

        coordinator.setStoreStatus(true)
        XCTAssertTrue(PaywallPacingEngine.shared.isProUser())
        XCTAssertTrue(AdPacingEngine.shared.isProUser())
    }

    func testCallbackNotification() {
        var callbackInvokedWith: Bool? = nil
        coordinator.onProStatusChanged = { isPro in
            callbackInvokedWith = isPro
        }

        coordinator.debugOverride = .forcePro
        XCTAssertEqual(callbackInvokedWith, true)

        coordinator.debugOverride = .forceFree
        XCTAssertEqual(callbackInvokedWith, false)
    }
}
