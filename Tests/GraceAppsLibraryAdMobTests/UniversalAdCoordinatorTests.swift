//
//  UniversalAdCoordinatorTests.swift
//  GraceAppsLibraryAdMobTests
//
//  Created by Grace Huang on 11/17/26.
//

import XCTest
@testable import GraceAppsLibrary
@testable import GraceAppsLibraryAdMob

private enum TestTrigger: String, CaseIterable {
    case quizCompletion = "quiz_completion"
    case timerStopped = "timer_stopped"
}

@MainActor
final class UniversalAdCoordinatorTests: XCTestCase {
    
    override func setUp() async throws {
        try await super.setUp()
        AdPacingEngine.shared.resetForTesting()
        AdPacingEngine.shared.config.isFirstRunExempt = false
    }
    
    override func tearDown() async throws {
        AdPacingEngine.shared.resetForTesting()
        try await super.tearDown()
    }
    
    func testAdUnitRegistrationAndResolution() {
        let coordinator = UniversalAdCoordinator.shared
        coordinator.adUnitMap.removeAll()
        
        XCTAssertNil(coordinator.resolveAdUnitID(for: "fast_completed"))
        
        coordinator.registerDefault(adUnitID: "ca-app-pub-default")
        XCTAssertEqual(coordinator.resolveAdUnitID(for: "fast_completed"), "ca-app-pub-default")
        
        coordinator.register(adUnitID: "ca-app-pub-fast", for: "fast_completed")
        XCTAssertEqual(coordinator.resolveAdUnitID(for: "fast_completed"), "ca-app-pub-fast")
        XCTAssertEqual(coordinator.resolveAdUnitID(for: "unknown_trigger"), "ca-app-pub-default")
    }
    
    func testConfigureOneLineSetup() {
        let coordinator = UniversalAdCoordinator.shared
        coordinator.configure(
            adUnits: [TestTrigger.quizCompletion.rawValue: "ca-app-pub-quiz"],
            defaultUnitID: "ca-app-pub-fallback",
            isPro: { true }
        )
        
        XCTAssertEqual(coordinator.resolveAdUnitID(for: TestTrigger.quizCompletion.rawValue), "ca-app-pub-quiz")
        XCTAssertEqual(coordinator.resolveAdUnitID(for: "other"), "ca-app-pub-fallback")
        XCTAssertTrue(coordinator.pacing.isProUser())
        XCTAssertFalse(coordinator.canShowAds)
    }
    
    func testGenericEnumOverloads() {
        let coordinator = UniversalAdCoordinator.shared
        coordinator.register(adUnitID: "ca-app-pub-timer", for: TestTrigger.timerStopped.rawValue)
        
        XCTAssertFalse(coordinator.isAdReady(for: TestTrigger.timerStopped))
        XCTAssertTrue(coordinator.shouldShowAd(for: TestTrigger.timerStopped))
        
        let action = UXAction.universalAd(trigger: TestTrigger.timerStopped)
        XCTAssertEqual(action.id, .interstitialAd)
        XCTAssertTrue(action.tags.contains(.ad))
    }
    
    func testIsAdReadyReturnsFalseWhenNoAdLoaded() {
        let coordinator = UniversalAdCoordinator.shared
        XCTAssertFalse(coordinator.isAdReady(for: "fast_completed"))
        XCTAssertFalse(coordinator.isAdReady(for: "default"))
    }
    
    func testPresentationBlockedWhenPacingEngineSuppresses() {
        let coordinator = UniversalAdCoordinator.shared
        coordinator.pacing.isProUser = { true }
        
        let expectation = expectation(description: "Ad presentation suppressed for pro user")
        let initiated = coordinator.present(for: "fast_completed") { presented in
            XCTAssertFalse(presented)
            expectation.fulfill()
        }
        
        XCTAssertFalse(initiated, "present(...) must return false synchronously when suppressed")
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testClearAllAdsResetsState() {
        let coordinator = UniversalAdCoordinator.shared
        coordinator.clearAllAds()
        
        XCTAssertFalse(coordinator.isShowingAd)
        XCTAssertFalse(coordinator.isInterstitialLoading)
        XCTAssertTrue(coordinator.cachedAds.isEmpty)
    }
    
    func testUXActionUniversalAdFactory() {
        let action = UXAction.universalAd(
            id: .interstitialAd,
            trigger: "fast_completed"
        )
        
        XCTAssertEqual(action.id, .interstitialAd)
        XCTAssertTrue(action.tags.contains(.ad))
        XCTAssertEqual(action.priority, UXActionPriority.ad)
    }
    
    func testTypealiasAdCoordinator() {
        let coordinator: AdCoordinator = UniversalAdCoordinator.shared
        XCTAssertTrue(coordinator === UniversalAdCoordinator.shared)
    }
}
