//
//  PaywallPacingEngineTests.swift
//  GraceAppsLibraryTests
//
//  Created by Grace Huang on 11/11/26.
//

import XCTest
@testable import GraceAppsLibrary

@MainActor
final class PaywallPacingEngineTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        PaywallPacingEngine.shared.resetForTesting()
    }
    
    override func tearDown() {
        PaywallPacingEngine.shared.resetForTesting()
        super.tearDown()
    }
    
    // MARK: - Direct Intent & Pro Suppression Tests
    
    func testDirectIntentAlwaysApprovedForFreeUser() {
        let engine = PaywallPacingEngine.shared
        engine.isProUser = { false }
        
        let approved = engine.canPresentPaywall(category: .directIntent)
        XCTAssertTrue(approved, "Direct user intent must always approve paywall for non-Pro users.")
    }
    
    func testDirectIntentSuppressedForProUser() {
        let engine = PaywallPacingEngine.shared
        engine.isProUser = { true }
        
        let approved = engine.canPresentPaywall(category: .directIntent)
        XCTAssertFalse(approved, "Direct intent must be suppressed if user already has Pro subscription.")
    }
    
    func testEndowmentThresholdApprovedForFreeUser() {
        let engine = PaywallPacingEngine.shared
        engine.isProUser = { false }
        
        let approved = engine.canPresentPaywall(category: .endowmentThreshold)
        XCTAssertTrue(approved, "Reaching endowment cap must approve paywall for free users.")
    }
    
    func testEndowmentThresholdSuppressedForProUser() {
        let engine = PaywallPacingEngine.shared
        engine.isProUser = { true }
        
        let approved = engine.canPresentPaywall(category: .endowmentThreshold)
        XCTAssertFalse(approved, "Endowment threshold must be suppressed for Pro users.")
    }
    
    // MARK: - Milestone Throttling Tests
    
    func testMilestoneFirstRunApproved() {
        let engine = PaywallPacingEngine.shared
        engine.isProUser = { false }
        
        let approved = engine.canPresentPaywall(category: .milestoneAchievement)
        XCTAssertTrue(approved, "First milestone activity completion ever must be approved.")
    }
    
    func testMilestoneSessionCapped() {
        let engine = PaywallPacingEngine.shared
        engine.isProUser = { false }
        
        // 1st offer shown
        let firstRun = engine.canPresentPaywall(category: .milestoneAchievement)
        XCTAssertTrue(firstRun)
        engine.recordMilestoneOfferPresented()
        
        // Next attempt in same session: throttled by session cap
        let secondRun = engine.canPresentPaywall(category: .milestoneAchievement)
        XCTAssertFalse(secondRun, "Milestone paywall must be throttled if already shown in current session.")
        
        // After session reset, still throttled by completion count interval
        engine.resetSession()
        let afterReset = engine.canPresentPaywall(category: .milestoneAchievement)
        XCTAssertFalse(afterReset, "After session reset, milestone must still be throttled until 3 completions are achieved.")
    }
    
    func testMilestoneReEligibleAfterCompletionInterval() {
        let engine = PaywallPacingEngine.shared
        engine.isProUser = { false }
        
        // First presentation
        XCTAssertTrue(engine.canPresentPaywall(category: .milestoneAchievement))
        engine.recordMilestoneOfferPresented()
        engine.resetSession()
        
        // Completion 1 & 2: not enough
        engine.recordActivityCompletion()
        XCTAssertFalse(engine.canPresentPaywall(category: .milestoneAchievement))
        
        engine.recordActivityCompletion()
        XCTAssertFalse(engine.canPresentPaywall(category: .milestoneAchievement))
        
        // Completion 3: meets default threshold of 3
        engine.recordActivityCompletion()
        XCTAssertTrue(engine.canPresentPaywall(category: .milestoneAchievement), "Milestone must become re-eligible after completion interval is met.")
    }
    
    // MARK: - Trigger Analytics Stats Tests
    
    func testTriggerStatsTracking() {
        let engine = PaywallPacingEngine.shared
        let triggerId = "deck_completion"
        
        let initial = engine.getTriggerStats(for: triggerId)
        
        engine.recordTriggerShown(triggerId)
        engine.recordTriggerPurchased(triggerId)
        engine.recordTriggerDismissed(triggerId)
        
        let updated = engine.getTriggerStats(for: triggerId)
        XCTAssertEqual(updated.shown, initial.shown + 1)
        XCTAssertEqual(updated.purchased, initial.purchased + 1)
        XCTAssertEqual(updated.dismissed, initial.dismissed + 1)
    }
    
    func testResetForTesting() {
        let engine = PaywallPacingEngine.shared
        engine.recordMilestoneOfferPresented()
        XCTAssertTrue(engine.hasShownMilestoneThisSession)
        
        engine.resetForTesting()
        XCTAssertFalse(engine.hasShownMilestoneThisSession)
        XCTAssertTrue(engine.canPresentPaywall(category: .milestoneAchievement))
    }
}
