//
//  UniversalAdCoordinatorTests.swift
//  GraceAppsLibraryAdMobTests
//
//  Created by Grace Huang on 11/17/26.
//

import XCTest
import UIKit
import GoogleMobileAds
@testable import GraceAppsLibrary
@testable import GraceAppsLibraryAdMob

private enum TestTrigger: String, CaseIterable {
    case quizCompletion = "quiz_completion"
    case timerStopped = "timer_stopped"
}

private final class MockUniversalPresentableAd: NSObject, UniversalPresentableAd, FullScreenPresentingAd {
    weak var fullScreenContentDelegate: FullScreenContentDelegate?
    var presentCalled = false
    var presentedFrom: UIViewController?
    
    func present(from rootViewController: UIViewController?) {
        presentCalled = true
        presentedFrom = rootViewController
    }
}

private final class MockPresentingViewController: UIViewController {
    var lastPresentedVC: UIViewController?
    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        lastPresentedVC = viewControllerToPresent
        completion?()
    }
}

private final class MockDismissingViewController: UIViewController {
    var isDismissingOverride: Bool = true
    override var isBeingDismissed: Bool {
        isDismissingOverride
    }
}

@MainActor
final class UniversalAdCoordinatorTests: XCTestCase {
    
    override func setUp() async throws {
        try await super.setUp()
        AdPacingEngine.shared.resetForTesting()
        AdPacingEngine.shared.config.isFirstRunExempt = false
        UniversalAdCoordinator.shared.clearAllAds()
        UniversalAdCoordinator.shared.adLoader = nil
        UniversalAdCoordinator.shared.topViewControllerResolver = nil
        #if DEBUG
        UniversalAdCoordinator.isMockPresentationEnabled = false
        #endif
    }
    
    override func tearDown() async throws {
        UniversalAdCoordinator.shared.clearAllAds()
        UniversalAdCoordinator.shared.adLoader = nil
        UniversalAdCoordinator.shared.topViewControllerResolver = nil
        #if DEBUG
        UniversalAdCoordinator.isMockPresentationEnabled = false
        #endif
        AdPacingEngine.shared.resetForTesting()
        try await super.tearDown()
    }
    
    // MARK: - Ad Unit Configuration
    
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
    
    func testCanShowAdsProperty() {
        let coordinator = UniversalAdCoordinator.shared
        coordinator.pacing.isProUser = { false }
        coordinator.pacing.setFlowPaywallSuppressed(false)
        XCTAssertTrue(coordinator.canShowAds)
        
        coordinator.pacing.isProUser = { true }
        XCTAssertFalse(coordinator.canShowAds)
        
        coordinator.pacing.isProUser = { false }
        coordinator.pacing.setFlowPaywallSuppressed(true)
        XCTAssertFalse(coordinator.canShowAds)
    }
    
    func testInitializeSDK() {
        let coordinator = UniversalAdCoordinator.shared
        let exp = expectation(description: "MobileAds start completes")
        coordinator.initialize { status in
            exp.fulfill()
        }
        wait(for: [exp], timeout: 10.0)
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
    
    // MARK: - Cache Hygiene & TTL Expiration
    
    func testIsAdReadyReturnsFalseWhenNoAdLoaded() {
        let coordinator = UniversalAdCoordinator.shared
        XCTAssertFalse(coordinator.isAdReady(for: "fast_completed"))
        XCTAssertFalse(coordinator.isAdReady(for: "default"))
    }
    
    func testCleanExpiredAdsEvictsStaleEntries() {
        let coordinator = UniversalAdCoordinator.shared
        let staleDate = Date().addingTimeInterval(-(coordinator.pacing.config.cacheTTL + 10))
        coordinator.adLoadDates["stale_trigger"] = staleDate
        
        XCTAssertEqual(coordinator.adLoadDates.count, 1)
        coordinator.cleanExpiredAds()
        XCTAssertNil(coordinator.adLoadDates["stale_trigger"])
        XCTAssertTrue(coordinator.adLoadDates.isEmpty)
    }
    
    // MARK: - JIT Preloading & Gatekeepers
    
    func testPreloadJITBlockedWhenUserIsPro() async {
        let coordinator = UniversalAdCoordinator.shared
        coordinator.pacing.isProUser = { true }
        coordinator.registerDefault(adUnitID: "ca-app-pub-default")
        
        await coordinator.preloadJIT(for: "fast_completed")
        XCTAssertFalse(coordinator.isInterstitialLoading)
        XCTAssertFalse(coordinator.isAdReady(for: "fast_completed"))
    }
    
    func testPreloadJITBlockedWhenNoAdUnitRegistered() async {
        let coordinator = UniversalAdCoordinator.shared
        coordinator.adUnitMap.removeAll()
        
        await coordinator.preloadJIT(for: "unregistered")
        XCTAssertFalse(coordinator.isInterstitialLoading)
    }
    
    func testPreloadJITSuccess() async {
        let coordinator = UniversalAdCoordinator.shared
        coordinator.registerDefault(adUnitID: "ca-app-pub-test-unit")
        let mockAd = MockUniversalPresentableAd()
        coordinator.adLoader = { unitID in
            XCTAssertEqual(unitID, "ca-app-pub-test-unit")
            return mockAd
        }
        
        await coordinator.preloadJIT(for: "default")
        XCTAssertTrue(coordinator.isAdReady(for: "default"))
        XCTAssertNotNil(coordinator.cachedAds["default"])
        XCTAssertIdentical(mockAd.fullScreenContentDelegate, coordinator)
    }
    
    func testPreloadJITGenericEnum() async {
        let coordinator = UniversalAdCoordinator.shared
        coordinator.register(adUnitID: "ca-app-pub-test-quiz", for: TestTrigger.quizCompletion.rawValue)
        let mockAd = MockUniversalPresentableAd()
        coordinator.adLoader = { _ in mockAd }
        
        await coordinator.preloadJIT(for: TestTrigger.quizCompletion)
        XCTAssertTrue(coordinator.isAdReady(for: TestTrigger.quizCompletion))
    }
    
    func testPreloadJITNetworkFailure() async {
        let coordinator = UniversalAdCoordinator.shared
        coordinator.registerDefault(adUnitID: "ca-app-pub-test-unit")
        coordinator.adLoader = { _ in
            throw NSError(domain: "test", code: -1009, userInfo: [NSLocalizedDescriptionKey: "No internet"])
        }
        
        await coordinator.preloadJIT(for: "default")
        XCTAssertFalse(coordinator.isAdReady(for: "default"))
    }
    
    func testPreloadJITAlreadyInFlight() async {
        let coordinator = UniversalAdCoordinator.shared
        coordinator.registerDefault(adUnitID: "ca-app-pub-test-unit")
        coordinator.activeLoadingTriggers.insert("default")
        
        await coordinator.preloadJIT(for: "default")
        XCTAssertFalse(coordinator.isAdReady(for: "default"))
    }
    
    func testPreloadAllAndLoadAdConvenience() {
        let coordinator = UniversalAdCoordinator.shared
        coordinator.preloadAll(triggers: TestTrigger.self)
        coordinator.loadAd()
    }
    
    // MARK: - Presentation Gatekeeping & Overloads
    
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
    
    func testPresentationFailsWhenAdNotCached() {
        let coordinator = UniversalAdCoordinator.shared
        coordinator.pacing.isProUser = { false }
        
        let expectation = expectation(description: "Ad presentation fails due to empty cache")
        let initiated = coordinator.present(for: "missing_cache") { presented in
            XCTAssertFalse(presented)
            expectation.fulfill()
        }
        
        XCTAssertFalse(initiated)
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testPresentSuccessFromCachedAd() {
        let coordinator = UniversalAdCoordinator.shared
        let mockAd = MockUniversalPresentableAd()
        coordinator.cachedAds["quiz"] = mockAd
        coordinator.adLoadDates["quiz"] = Date()
        
        let hostVC = UIViewController()
        let initiated = coordinator.present(for: "quiz", from: hostVC) { _ in }
        
        XCTAssertTrue(initiated)
        XCTAssertTrue(mockAd.presentCalled)
        XCTAssertIdentical(mockAd.presentedFrom, hostVC)
        XCTAssertTrue(coordinator.isShowingAd)
        XCTAssertNil(coordinator.cachedAds["quiz"])
    }
    
    func testPresentTransitionDelayWhenHostIsDismissing() {
        let coordinator = UniversalAdCoordinator.shared
        let mockAd = MockUniversalPresentableAd()
        coordinator.cachedAds["quiz"] = mockAd
        coordinator.adLoadDates["quiz"] = Date()
        
        let hostVC = MockDismissingViewController()
        let settledVC = UIViewController()
        coordinator.topViewControllerResolver = { settledVC }
        
        let exp = expectation(description: "delayed presentation")
        let initiated = coordinator.present(for: "quiz", from: hostVC) { presented in
            XCTAssertTrue(presented)
            exp.fulfill()
        }
        
        XCTAssertTrue(initiated)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            XCTAssertTrue(mockAd.presentCalled)
            XCTAssertIdentical(mockAd.presentedFrom, settledVC)
            coordinator.adDidDismissFullScreenContent(mockAd)
        }
        
        wait(for: [exp], timeout: 2.0)
    }
    
    func testPresentTransitionDelayFailedToResolveTopVC() {
        let coordinator = UniversalAdCoordinator.shared
        let mockAd = MockUniversalPresentableAd()
        coordinator.cachedAds["quiz"] = mockAd
        coordinator.adLoadDates["quiz"] = Date()
        
        let hostVC = MockDismissingViewController()
        coordinator.topViewControllerResolver = { nil }
        
        let exp = expectation(description: "delayed presentation failure")
        let initiated = coordinator.present(for: "quiz", from: hostVC) { presented in
            XCTAssertFalse(presented)
            exp.fulfill()
        }
        
        XCTAssertTrue(initiated)
        wait(for: [exp], timeout: 1.5)
        XCTAssertFalse(coordinator.isShowingAd)
    }
    
    func testPresentFailsWhenTopVCCannotBeResolved() {
        let coordinator = UniversalAdCoordinator.shared
        let mockAd = MockUniversalPresentableAd()
        coordinator.cachedAds["quiz"] = mockAd
        coordinator.topViewControllerResolver = { nil }
        
        let exp = expectation(description: "cannot resolve top VC")
        let initiated = coordinator.present(for: "quiz", from: nil) { presented in
            XCTAssertFalse(presented)
            exp.fulfill()
        }
        XCTAssertFalse(initiated)
        wait(for: [exp], timeout: 1.0)
    }
    
    func testMockAdPresentationFlag() {
        let coordinator = UniversalAdCoordinator.shared
        #if DEBUG
        UniversalAdCoordinator.isMockPresentationEnabled = true
        #endif
        
        let hostVC = MockPresentingViewController()
        let exp = expectation(description: "mock presentation completes")
        let initiated = coordinator.present(for: "quiz", from: hostVC) { presented in
            XCTAssertTrue(presented)
            exp.fulfill()
        }
        XCTAssertTrue(initiated)
        XCTAssertTrue(coordinator.isShowingAd)
        
        if let mockAdVC = hostVC.lastPresentedVC as? MockInterstitialAdViewController {
            mockAdVC.simulateDismissal()
        }
        
        wait(for: [exp], timeout: 1.5)
        XCTAssertFalse(coordinator.isShowingAd)
    }
    
    func testMockAdPresentationWithDismissingHostVC() {
        let coordinator = UniversalAdCoordinator.shared
        #if DEBUG
        UniversalAdCoordinator.isMockPresentationEnabled = true
        #endif
        
        let hostVC = MockDismissingViewController()
        let settledVC = MockPresentingViewController()
        coordinator.topViewControllerResolver = { settledVC }
        
        let exp = expectation(description: "delayed mock presentation completes")
        let initiated = coordinator.present(for: "quiz", from: hostVC) { presented in
            XCTAssertTrue(presented)
            exp.fulfill()
        }
        XCTAssertTrue(initiated)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            if let mockAdVC = settledVC.lastPresentedVC as? MockInterstitialAdViewController {
                mockAdVC.simulateDismissal()
            }
        }
        
        wait(for: [exp], timeout: 2.0)
    }
    
    func testMockPresentationSuppressedWhenPro() {
        let coordinator = UniversalAdCoordinator.shared
        #if DEBUG
        UniversalAdCoordinator.isMockPresentationEnabled = true
        #endif
        coordinator.pacing.isProUser = { true }
        
        let exp = expectation(description: "mock suppressed")
        let initiated = coordinator.present(for: "quiz") { presented in
            XCTAssertFalse(presented)
            exp.fulfill()
        }
        XCTAssertFalse(initiated)
        wait(for: [exp], timeout: 1.0)
    }
    
    func testMockPresentationFailsWithoutHostVC() {
        let coordinator = UniversalAdCoordinator.shared
        #if DEBUG
        UniversalAdCoordinator.isMockPresentationEnabled = true
        #endif
        coordinator.topViewControllerResolver = { nil }
        
        let exp = expectation(description: "no host VC")
        let initiated = coordinator.present(for: "quiz", from: nil) { presented in
            XCTAssertFalse(presented)
            exp.fulfill()
        }
        XCTAssertFalse(initiated)
        wait(for: [exp], timeout: 1.0)
    }
    
    func testShowAdAndPresentOverloads() {
        let coordinator = UniversalAdCoordinator.shared
        
        let exp1 = expectation(description: "showAd string")
        coordinator.showAd(for: "test") { presented in
            XCTAssertFalse(presented)
            exp1.fulfill()
        }
        
        let exp2 = expectation(description: "showAd trigger label")
        coordinator.showAd(trigger: "test") { presented in
            XCTAssertFalse(presented)
            exp2.fulfill()
        }
        
        let exp3 = expectation(description: "present trigger label")
        let init3 = coordinator.present(trigger: "test") { presented in
            XCTAssertFalse(presented)
            exp3.fulfill()
        }
        XCTAssertFalse(init3)
        
        let exp4 = expectation(description: "showAd enum")
        coordinator.showAd(for: TestTrigger.quizCompletion) { presented in
            XCTAssertFalse(presented)
            exp4.fulfill()
        }
        
        let exp5 = expectation(description: "showAd enum trigger label")
        coordinator.showAd(trigger: TestTrigger.quizCompletion) { presented in
            XCTAssertFalse(presented)
            exp5.fulfill()
        }
        
        let exp6 = expectation(description: "present enum")
        let init6 = coordinator.present(for: TestTrigger.quizCompletion) { presented in
            XCTAssertFalse(presented)
            exp6.fulfill()
        }
        XCTAssertFalse(init6)
        
        let exp7 = expectation(description: "present enum trigger label")
        let init7 = coordinator.present(trigger: TestTrigger.quizCompletion) { presented in
            XCTAssertFalse(presented)
            exp7.fulfill()
        }
        XCTAssertFalse(init7)
        
        wait(for: [exp1, exp2, exp3, exp4, exp5, exp6, exp7], timeout: 1.0)
    }
    
    func testPresentAdAndLoadNextAd() {
        let coordinator = UniversalAdCoordinator.shared
        coordinator.presentAdAndLoadNextAd(shouldPresent: false)
        coordinator.presentAdAndLoadNextAd(shouldPresent: true)
    }
    
    func testClearAllAdsResetsState() {
        let coordinator = UniversalAdCoordinator.shared
        coordinator.clearAllAds()
        
        XCTAssertFalse(coordinator.isShowingAd)
        XCTAssertFalse(coordinator.isInterstitialLoading)
        XCTAssertTrue(coordinator.cachedAds.isEmpty)
    }
    
    // MARK: - FullScreenContentDelegate Events
    
    func testFullScreenContentDelegateLifecycle() async {
        let coordinator = UniversalAdCoordinator.shared
        let mockAd = MockUniversalPresentableAd()
        
        coordinator.adWillPresentFullScreenContent(mockAd)
        await Task.yield()
        XCTAssertTrue(coordinator.isShowingAd)
        
        coordinator.adDidRecordImpression(mockAd)
        coordinator.adDidRecordClick(mockAd)
        coordinator.adWillDismissFullScreenContent(mockAd)
        
        let exp = expectation(description: "dismissal callback called")
        coordinator.activeDismissalCallback = { presented in
            XCTAssertTrue(presented)
            exp.fulfill()
        }
        coordinator.activePresentingTrigger = "quiz"
        
        coordinator.adDidDismissFullScreenContent(mockAd)
        
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertFalse(coordinator.isShowingAd)
        XCTAssertNil(coordinator.activeDismissalCallback)
        XCTAssertNil(coordinator.activePresentingTrigger)
    }
    
    func testFullScreenContentDelegateFailure() async {
        let coordinator = UniversalAdCoordinator.shared
        let mockAd = MockUniversalPresentableAd()
        let error = NSError(domain: "test", code: -1, userInfo: nil)
        
        let exp = expectation(description: "failure callback called")
        coordinator.activeDismissalCallback = { presented in
            XCTAssertFalse(presented)
            exp.fulfill()
        }
        
        coordinator.ad(mockAd, didFailToPresentFullScreenContentWithError: error)
        
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertFalse(coordinator.isShowingAd)
        XCTAssertNil(coordinator.activeDismissalCallback)
    }
    
    func testFullScreenContentDelegateDidDismissWithoutActiveTriggerFallback() async {
        let coordinator = UniversalAdCoordinator.shared
        let mockAd = MockUniversalPresentableAd()
        coordinator.activePresentingTrigger = nil
        let exp = expectation(description: "dismissal fallback")
        coordinator.activeDismissalCallback = { _ in exp.fulfill() }
        coordinator.adDidDismissFullScreenContent(mockAd)
        await fulfillment(of: [exp], timeout: 1.0)
    }
    
    // MARK: - UXAction Integration & Execution
    
    func testUXActionUniversalAdFactoryAndSkippedExecution() async {
        let coordinator = UniversalAdCoordinator.shared
        coordinator.pacing.isProUser = { true }
        
        let action = UXAction.universalAd(
            id: .interstitialAd,
            trigger: "fast_completed",
            coordinator: coordinator
        )
        
        XCTAssertEqual(action.id, .interstitialAd)
        XCTAssertTrue(action.tags.contains(.ad))
        XCTAssertEqual(action.priority, UXActionPriority.ad)
        XCTAssertEqual(action.kind, .customAsync)
        
        let exp = expectation(description: "action execution completion")
        action.executionBlock? { outcome in
            XCTAssertEqual(outcome, .skipped)
            exp.fulfill()
        }
        
        await fulfillment(of: [exp], timeout: 1.0)
    }
    
    func testUXActionUniversalAdExecutedSuccessfully() async {
        let coordinator = UniversalAdCoordinator.shared
        let mockAd = MockUniversalPresentableAd()
        coordinator.cachedAds["quiz"] = mockAd
        coordinator.adLoadDates["quiz"] = Date()
        
        let hostVC = MockPresentingViewController()
        coordinator.topViewControllerResolver = { hostVC }
        let action = UXAction.universalAd(id: .interstitialAd, trigger: "quiz", coordinator: coordinator)
        
        let exp = expectation(description: "action completed")
        action.executionBlock? { outcome in
            XCTAssertEqual(outcome, .completed)
            exp.fulfill()
        }
        
        XCTAssertTrue(mockAd.presentCalled)
        coordinator.adDidDismissFullScreenContent(mockAd)
        await fulfillment(of: [exp], timeout: 1.0)
    }
    
    func testTypealiasAdCoordinator() {
        let coordinator: AdCoordinator = UniversalAdCoordinator.shared
        XCTAssertTrue(coordinator === UniversalAdCoordinator.shared)
    }
}
