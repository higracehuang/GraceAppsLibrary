//
//  AdPacingEngineTests.swift
//  GraceAppsLibraryTests
//
//  Created by Grace Huang on 11/11/26.
//

import XCTest
@testable import GraceAppsLibrary

@MainActor
final class AdPacingEngineTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        AdPacingEngine.shared.resetForTesting()
    }
    
    override func tearDown() {
        AdPacingEngine.shared.resetForTesting()
        super.tearDown()
    }
    
    // MARK: - Preload Gatekeeper Tests (Zero Waste)
    
    func testPreloadSkippedForProUser() {
        let engine = AdPacingEngine.shared
        engine.isProUser = { true }
        
        let canPreload = engine.canPreloadAd(for: "after_quiz", isCacheValid: false)
        XCTAssertFalse(canPreload, "Preload must be blocked for Pro users to prevent wasted ad requests.")
    }
    
    func testPreloadSkippedWhenFlowPaywallActive() {
        let engine = AdPacingEngine.shared
        engine.setFlowPaywallSuppressed(true)
        
        let canPreload = engine.canPreloadAd(for: "after_quiz", isCacheValid: false)
        XCTAssertFalse(canPreload, "Preload must be blocked when paywall is active in the flow.")
    }
    
    func testPreloadSkippedWhenCacheAlreadyFresh() {
        let engine = AdPacingEngine.shared
        
        let canPreload = engine.canPreloadAd(for: "after_quiz", isCacheValid: true)
        XCTAssertFalse(canPreload, "Preload must be blocked if an unexpired ad is already cached in memory.")
    }
    
    func testPreloadApprovedWhenEligible() {
        let engine = AdPacingEngine.shared
        engine.isProUser = { false }
        
        let canPreload = engine.canPreloadAd(for: "after_quiz", isCacheValid: false)
        XCTAssertTrue(canPreload, "Preload should be approved when user is free, cache empty, and flow clear.")
    }
    
    // MARK: - Presentation Gatekeeper Tests
    
    func testPresentationSuppressedForProUser() {
        let engine = AdPacingEngine.shared
        engine.isProUser = { true }
        
        let canPresent = engine.canPresentAd(for: "after_quiz")
        XCTAssertFalse(canPresent, "Presentation must be suppressed for Pro users.")
    }
    
    func testPresentationSuppressedWhenFlowPaywallActive() {
        let engine = AdPacingEngine.shared
        engine.setFlowPaywallSuppressed(true)
        
        let canPresent = engine.canPresentAd(for: "after_quiz")
        XCTAssertFalse(canPresent, "Presentation must be suppressed when flow showed paywall.")
    }
    
    func testFirstRunExemptionSuppressesFirstAd() {
        let engine = AdPacingEngine.shared
        engine.config.isFirstRunExempt = true
        
        // 1st presentation on first run: suppressed by onboarding grace period
        let firstRun = engine.canPresentAd(for: "after_quiz")
        XCTAssertFalse(firstRun, "First-run onboarding exemption must suppress the first ad.")
        
        // 2nd presentation: now eligible!
        let secondRun = engine.canPresentAd(for: "after_quiz")
        XCTAssertTrue(secondRun, "Subsequent ad after first-run exemption should be approved.")
    }
    
    func testSafetyDebounceSuppressesRapidFireAds() {
        let engine = AdPacingEngine.shared
        engine.config.isFirstRunExempt = false
        engine.config.safetyDebounce = 20.0
        
        // 1st ad presented
        XCTAssertTrue(engine.canPresentAd(for: "trigger_a"))
        engine.recordAdPresented(for: "trigger_a")
        
        // Immediate 2nd ad on different trigger: suppressed by safety debounce
        let immediateAd = engine.canPresentAd(for: "trigger_b")
        XCTAssertFalse(immediateAd, "Safety debounce must suppress ad presentations within 20s.")
    }
    
    func testTriggerCooldownSuppressesRepeatedTrigger() {
        let engine = AdPacingEngine.shared
        engine.config.isFirstRunExempt = false
        engine.config.safetyDebounce = 0.0 // Disable debounce to test trigger cooldown in isolation
        engine.config.triggerCooldown = 120.0
        
        // 1st ad on trigger
        XCTAssertTrue(engine.canPresentAd(for: "after_practice"))
        engine.recordAdPresented(for: "after_practice")
        
        // Repeated ad on same trigger: suppressed by cooldown
        let repeatedAd = engine.canPresentAd(for: "after_practice")
        XCTAssertFalse(repeatedAd, "Trigger cooldown must suppress repeated ads on the same trigger within 120s.")
    }
    
    func testSessionCapLimitsTotalAds() {
        let engine = AdPacingEngine.shared
        engine.config.isFirstRunExempt = false
        engine.config.safetyDebounce = 0.0
        engine.config.triggerCooldown = 0.0
        engine.config.maxPerSession = 2
        
        // Ad 1
        XCTAssertTrue(engine.canPresentAd(for: "t1"))
        engine.recordAdPresented(for: "t1")
        
        // Ad 2
        XCTAssertTrue(engine.canPresentAd(for: "t2"))
        engine.recordAdPresented(for: "t2")
        
        // Ad 3: exceeded session cap
        XCTAssertFalse(engine.canPresentAd(for: "t3"), "Session cap must suppress ads beyond maxPerSession.")
        XCTAssertFalse(engine.canPreloadAd(for: "t3", isCacheValid: false), "Session cap must also block preloading.")
    }
    
    func testResetSessionClearsCounts() {
        let engine = AdPacingEngine.shared
        engine.config.isFirstRunExempt = false
        engine.config.maxPerSession = 1
        
        XCTAssertTrue(engine.canPresentAd(for: "t1"))
        engine.recordAdPresented(for: "t1")
        XCTAssertEqual(engine.sessionAdCount, 1)
        
        engine.setFlowPaywallSuppressed(true)
        XCTAssertTrue(engine.isFlowPaywallSuppressed)
        
        // Reset session
        engine.resetSession()
        XCTAssertEqual(engine.sessionAdCount, 0)
        XCTAssertFalse(engine.isFlowPaywallSuppressed)
    }
}
