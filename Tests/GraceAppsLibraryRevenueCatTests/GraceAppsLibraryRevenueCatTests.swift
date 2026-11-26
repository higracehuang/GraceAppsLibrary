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

    func testInterstitialAdPreconditionAutoWiring() {
        UXFlowOrchestrator.shared.resetForTesting()
        coordinator.wirePacingEngines()
        coordinator.debugOverride = .automatic

        // Free user: precondition allows interstitialAd
        coordinator.setStoreStatus(false)
        XCTAssertEqual(UXFlowOrchestrator.shared.policy.preconditions[.interstitialAd]?(), true)

        var adExecuted = false
        let freeExp = expectation(description: "Interstitial ad runs for free user")
        UXFlowOrchestrator.shared.requestActions([
            UXAction(id: .interstitialAd, priority: .ad, kind: .customAsync, tags: [.ad]) { completion in
                adExecuted = true
                completion(.completed)
            }
        ]) {
            freeExp.fulfill()
        }
        wait(for: [freeExp], timeout: 2.0)
        XCTAssertTrue(adExecuted)

        // Pro user: precondition suppresses interstitialAd
        UXFlowOrchestrator.shared.resetForTesting()
        coordinator.wirePacingEngines()
        coordinator.setStoreStatus(true)
        XCTAssertEqual(UXFlowOrchestrator.shared.policy.preconditions[.interstitialAd]?(), false)

        var proAdExecuted = false
        let proExp = expectation(description: "Interstitial ad suppressed for Pro user")
        UXFlowOrchestrator.shared.requestActions([
            UXAction(id: .interstitialAd, priority: .ad, kind: .customAsync, tags: [.ad]) { completion in
                proAdExecuted = true
                completion(.completed)
            }
        ]) {
            proExp.fulfill()
        }
        wait(for: [proExp], timeout: 2.0)
        XCTAssertFalse(proAdExecuted)
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
            features: [
                UniversalSubscriptionFeature(icon: "person.2.fill", title: "Unlimited Helpers"),
                UniversalSubscriptionFeature(icon: "repeat", title: "Automated Schedules")
            ]
        )
        XCTAssertEqual(heroSection.style, .hero)
        XCTAssertFalse(heroSection.showHeader)
        XCTAssertEqual(heroSection.features.count, 2)

        let compactSection = UniversalSubscriptionSection(
            style: .compact
        )
        XCTAssertEqual(compactSection.style, .compact)
        XCTAssertTrue(compactSection.showHeader)

        // Verify localization bundle and keys exist
        let bundle = Bundle.graceAppsLibrary
        let titleEn = bundle.localizedString(forKey: "subscription.section_title", value: nil, table: nil)
        XCTAssertEqual(titleEn, "Pro")

        let manageEn = bundle.localizedString(forKey: "subscription.manage", value: nil, table: nil)
        XCTAssertEqual(manageEn, "Manage Purchase")

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

    func testReleaseNotesConfigureWithPaywallDefaults() {
        let notes = [ReleaseNote(version: "1.0.0", notes: ["Initial release"])]
        ReleaseNotesManager.shared.configureWithPaywall(releaseNotes: notes)
        XCTAssertEqual(ReleaseNotesManager.shared.configuredReleaseNotes.count, 1)
        XCTAssertEqual(ReleaseNotesManager.shared.configuredReleaseNotes.first?.version, "1.0.0")

        ReleaseNotesManager.shared.configureWithPaywall(
            releaseNotes: notes,
            trigger: TestPaywallTrigger.settingsUpgrade
        )
        XCTAssertEqual(ReleaseNotesManager.shared.configuredReleaseNotes.count, 1)
    }

    private enum TestLimitKey: String {
        case photoSets = "photo_sets"
        case photosPerSet = "photos_per_set"
    }

    func testFreeTierLimitsForFreeAndProUsers() {
        coordinator.configureLimits(["photo_sets": 2])
        coordinator.debugOverride = .automatic

        // Free user: allowed below limit, blocked at or above limit
        coordinator.setStoreStatus(false)
        XCTAssertTrue(coordinator.isWithinFreeLimit("photo_sets", currentCount: 0))
        XCTAssertTrue(coordinator.isWithinFreeLimit("photo_sets", currentCount: 1))
        XCTAssertFalse(coordinator.isWithinFreeLimit("photo_sets", currentCount: 2))
        XCTAssertFalse(coordinator.isWithinFreeLimit("photo_sets", currentCount: 5))
        XCTAssertTrue(coordinator.isWithinFreeLimit("unconfigured_key", currentCount: 999))

        // Pro user: always allowed regardless of count
        coordinator.setStoreStatus(true)
        XCTAssertTrue(coordinator.isWithinFreeLimit("photo_sets", currentCount: 2))
        XCTAssertTrue(coordinator.isWithinFreeLimit("photo_sets", currentCount: 100))

        // Enum overload
        coordinator.configureLimits([TestLimitKey.photosPerSet: 10])
        coordinator.setStoreStatus(false)
        XCTAssertTrue(coordinator.isWithinFreeLimit(TestLimitKey.photosPerSet, currentCount: 9))
        XCTAssertFalse(coordinator.isWithinFreeLimit(TestLimitKey.photosPerSet, currentCount: 10))
        XCTAssertTrue(coordinator.checkLimitOrPresentPaywall(TestLimitKey.photosPerSet, currentCount: 9))
        XCTAssertFalse(coordinator.checkLimitOrPresentPaywall(TestLimitKey.photosPerSet, currentCount: 10))

        coordinator.configureLimits([String: Int]())
    }

    func testEarnedCreditsAndUsageTracking() {
        coordinator.configureLimits([TestLimitKey.photoSets: 2])
        coordinator.resetCreditsAndUsage(for: TestLimitKey.photoSets)
        coordinator.debugOverride = .automatic
        coordinator.setStoreStatus(false)

        XCTAssertEqual(coordinator.remainingFreeLimit(for: TestLimitKey.photoSets), 2)
        XCTAssertTrue(coordinator.isWithinFreeLimit(TestLimitKey.photoSets))

        coordinator.recordUsage(for: TestLimitKey.photoSets)
        coordinator.recordUsage(for: TestLimitKey.photoSets)
        XCTAssertEqual(coordinator.remainingFreeLimit(for: TestLimitKey.photoSets), 0)
        XCTAssertFalse(coordinator.isWithinFreeLimit(TestLimitKey.photoSets))

        coordinator.earnCredits(1, for: TestLimitKey.photoSets)
        XCTAssertEqual(coordinator.earnedCredits(for: TestLimitKey.photoSets), 1)
        XCTAssertEqual(coordinator.remainingFreeLimit(for: TestLimitKey.photoSets), 1)
        XCTAssertTrue(coordinator.isWithinFreeLimit(TestLimitKey.photoSets))

        coordinator.resetCreditsAndUsage(for: TestLimitKey.photoSets)
        XCTAssertEqual(coordinator.recordedUsage(for: TestLimitKey.photoSets), 0)
        XCTAssertEqual(coordinator.earnedCredits(for: TestLimitKey.photoSets), 0)
        coordinator.configureLimits([String: Int]())
    }
}
