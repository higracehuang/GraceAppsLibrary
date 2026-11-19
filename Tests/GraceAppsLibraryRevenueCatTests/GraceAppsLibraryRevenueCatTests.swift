import XCTest
import SwiftUI
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

    func testUniversalDebugViewsInitialization() {
        let menu = UniversalDebugMenu()
        XCTAssertEqual(menu.navigationTitle, "Debug Menu")

        let link = UniversalDebugLink()
        XCTAssertEqual(link.title, "Debug Menu")
        XCTAssertEqual(link.systemImage, "ladybug")

        let section = UniversalDeveloperSection()
        XCTAssertEqual(section.title, "Developer")

        let sectionWithCustom = UniversalDeveloperSection(title: "Custom Developer") {
            Text(verbatim: "Custom Tool")
        }
        XCTAssertEqual(sectionWithCustom.title, "Custom Developer")
    }

    func testUniversalSubscriptionSectionInitialization() {
        let heroSection = UniversalSubscriptionSection(
            style: .hero,
            tierName: "TallyCoin Pro",
            features: [
                UniversalSubscriptionFeature(icon: "person.2.fill", title: "Unlimited Helpers"),
                UniversalSubscriptionFeature(icon: "repeat", title: "Automated Schedules")
            ]
        )
        XCTAssertEqual(heroSection.style, .hero)
        XCTAssertFalse(heroSection.showHeader)
        XCTAssertEqual(heroSection.features.count, 2)

        let compactSection = UniversalSubscriptionSection(
            style: .compact,
            tierName: "DialIn Pro"
        )
        XCTAssertEqual(compactSection.style, .compact)
        XCTAssertTrue(compactSection.showHeader)

        // Verify localization bundle and keys exist
        let bundle = Bundle.graceAppsLibrary
        let titleEn = bundle.localizedString(forKey: "subscription.section_title", value: nil, table: nil)
        XCTAssertEqual(titleEn, "Subscription")

        let manageEn = bundle.localizedString(forKey: "subscription.manage", value: nil, table: nil)
        XCTAssertEqual(manageEn, "Manage Subscription")

        let activeEn = bundle.localizedString(forKey: "subscription.active", value: nil, table: nil)
        XCTAssertEqual(activeEn, "Active")
    }

    enum TestPaywallTrigger: String {
        case settingsUpgrade = "settings_upgrade"
        case statsUpgrade = "stats_upgrade"
    }

    func testUniversalPaywallModifierConfiguration() {
        var isPresented = false
        let binding = Binding(get: { isPresented }, set: { isPresented = $0 })

        // String trigger
        let viewWithString = EmptyView().universalPaywall(isPresented: binding, trigger: "test_trigger")
        XCTAssertNotNil(viewWithString)

        // RawRepresentable Enum trigger
        let viewWithEnum = EmptyView().universalPaywall(isPresented: binding, trigger: TestPaywallTrigger.settingsUpgrade)
        XCTAssertNotNil(viewWithEnum)
    }

    func testUXActionPaywallFactoryAndPresenter() {
        let action = UXAction.paywall(trigger: "test_trigger")
        XCTAssertEqual(action.id, .paywall)
        XCTAssertEqual(action.priority, .critical)
        XCTAssertEqual(action.kind, .sheet)
        XCTAssertTrue(action.tags.contains(.paywall))

        let enumAction = UXAction.paywall(trigger: TestPaywallTrigger.settingsUpgrade)
        XCTAssertEqual(enumAction.id, .paywall)
        XCTAssertEqual(enumAction.priority, .critical)
        XCTAssertTrue(enumAction.tags.contains(.paywall))

        // Ensure PaywallPresenter typealias points to UniversalPaywallPresenter
        let isSameType = (PaywallPresenter.self == UniversalPaywallPresenter.self)
        XCTAssertTrue(isSameType)
    }
}
