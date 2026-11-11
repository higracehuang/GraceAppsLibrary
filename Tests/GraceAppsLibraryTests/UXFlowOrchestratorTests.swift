//
//  UXFlowOrchestratorTests.swift
//  GraceAppsLibraryTests
//
//  Created by Grace Huang on 11/11/26.
//

import XCTest
import SwiftUI
@testable import GraceAppsLibrary

@MainActor
final class UXFlowOrchestratorTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        UXFlowOrchestrator.shared.resetForTesting()
        UXFlowOrchestrator.shared.interPresentationDelay = 0.01 // Fast settling in tests
    }
    
    override func tearDown() {
        UXFlowOrchestrator.shared.resetForTesting()
        super.tearDown()
    }
    
    func testPriorityOrdering() {
        let orchestrator = UXFlowOrchestrator.shared
        
        var executionOrder: [String] = []
        
        let actionAd = UXAction(id: "ad", priority: .ad, kind: .customAsync) { completion in
            executionOrder.append("ad")
            completion(.completed)
        }
        let actionPaywall = UXAction(id: "paywall", priority: .paywall, kind: .customAsync) { completion in
            executionOrder.append("paywall")
            completion(.completed)
        }
        let actionMilestone = UXAction(id: "milestone", priority: .milestone, kind: .customAsync) { completion in
            executionOrder.append("milestone")
            completion(.completed)
        }
        let actionReview = UXAction(id: "review", priority: .review, kind: .customAsync) { completion in
            executionOrder.append("review")
            completion(.completed)
        }
        
        // Pass in random order
        orchestrator.triggerFlow(actions: [actionAd, actionPaywall, actionReview, actionMilestone])
        
        // Milestone (750) should be presented first immediately
        XCTAssertEqual(executionOrder.first, "milestone", "Milestone (750) must execute before lower priority actions.")
    }
    
    func testMutualExclusionSuppressesConflictingTags() {
        let orchestrator = UXFlowOrchestrator.shared
        orchestrator.policy.mutuallyExclude(triggerTag: "paywall", suppressTag: "ad")
        
        var presentedActions: [String] = []
        
        let paywallAction = UXAction(id: "paywall", priority: .paywall, kind: .customAsync, tags: ["paywall"]) { completion in
            presentedActions.append("paywall")
            completion(.completed)
        }
        
        let adAction = UXAction(id: "ad", priority: .ad, kind: .customAsync, tags: ["ad"]) { completion in
            presentedActions.append("ad")
            completion(.completed)
        }
        
        orchestrator.triggerFlow(actions: [paywallAction, adAction])
        
        XCTAssertEqual(presentedActions, ["paywall"])
        
        // Fast-forward settling delay
        let exp = expectation(description: "Wait for pipeline settling")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            XCTAssertFalse(presentedActions.contains("ad"), "Ad must be suppressed because paywall ran in the same flow.")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }
    
    func testPreconditionEvaluation() {
        let orchestrator = UXFlowOrchestrator.shared
        
        var isProUser = true
        orchestrator.policy.setPrecondition(actionId: "paywall") { !isProUser }
        
        var paywallRan = false
        let paywall = UXAction(id: "paywall", priority: .paywall, kind: .customAsync) { completion in
            paywallRan = true
            completion(.completed)
        }
        
        orchestrator.triggerFlow(actions: [paywall])
        XCTAssertFalse(paywallRan, "Precondition returning false must reject action.")
        
        // Turn off Pro: now eligible
        isProUser = false
        orchestrator.triggerFlow(actions: [paywall])
        XCTAssertTrue(paywallRan, "Precondition returning true must allow action.")
    }
    
    func testSessionCapThrottling() {
        let orchestrator = UXFlowOrchestrator.shared
        orchestrator.policy.setSessionCap(actionId: "milestone_offer", maxCount: 1)
        
        var runCount = 0
        let action = UXAction(id: "milestone_offer", priority: .milestone, kind: .customAsync) { completion in
            runCount += 1
            completion(.completed)
        }
        
        // 1st execution: approved
        orchestrator.triggerFlow(actions: [action])
        XCTAssertEqual(runCount, 1)
        
        // Wait for settling
        let exp = expectation(description: "Settling")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            // 2nd execution in same session: throttled by session cap
            orchestrator.triggerFlow(actions: [action])
            XCTAssertEqual(runCount, 1, "Session cap must prevent 2nd execution in same session.")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }
    
    func testSheetPresentationAndOnDismissLifecycle() {
        let orchestrator = UXFlowOrchestrator.shared
        
        let sheetAction = UXAction(id: "results_sheet", priority: .milestone, kind: .sheet) {
            Text("Quiz Results")
        }
        
        orchestrator.triggerFlow(actions: [sheetAction])
        
        XCTAssertTrue(orchestrator.isBusy)
        XCTAssertEqual(orchestrator.currentActionId, "results_sheet")
        XCTAssertNotNil(orchestrator.activeSheetItem)
        XCTAssertEqual(orchestrator.activeSheetItem?.id, "results_sheet")
        
        // Simulate sheet dismissal
        orchestrator.onModalDismissed(actionId: "results_sheet")
        XCTAssertNil(orchestrator.activeSheetItem)
        
        let exp = expectation(description: "Settling after modal dismiss")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            XCTAssertFalse(orchestrator.isBusy)
            XCTAssertNil(orchestrator.currentActionId)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }
    
    func testChainedSheetFollowedBySystemDialogDoesNotCancelOut() {
        let orchestrator = UXFlowOrchestrator.shared
        
        var reviewPromptFired = false
        
        let sheetAction = UXAction(id: "celebration", priority: .milestone, kind: .sheet) {
            Text("Celebration")
        }
        
        let reviewAction = UXAction(id: "review", priority: .review, kind: .systemDialog) { completion in
            reviewPromptFired = true
            completion(.completed)
        }
        
        // Trigger both at once
        orchestrator.triggerFlow(actions: [sheetAction, reviewAction])
        
        // Sheet must be active first
        XCTAssertEqual(orchestrator.activeSheetItem?.id, "celebration")
        XCTAssertFalse(reviewPromptFired, "Review prompt must wait until celebration sheet finishes.")
        
        // Dismiss sheet
        orchestrator.onModalDismissed(actionId: "celebration")
        
        // Settle and verify review prompt runs next without cancellation
        let exp = expectation(description: "Chained review prompt execution")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            XCTAssertTrue(reviewPromptFired, "Review prompt must fire cleanly after sheet dismisses.")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }
    
    func testFlowCompletionCallbackInvokedWhenQueueEmpties() {
        let orchestrator = UXFlowOrchestrator.shared
        
        var flowCompleted = false
        var executionOrder: [String] = []
        
        let sheetAction = UXAction(id: "celebration", priority: .milestone, kind: .sheet) {
            Text("Celebration")
        }
        let asyncAction = UXAction(id: "ad", priority: .ad, kind: .customAsync) { completion in
            executionOrder.append("ad")
            completion(.completed)
        }
        
        orchestrator.requestActions([sheetAction, asyncAction]) {
            flowCompleted = true
        }
        
        XCTAssertEqual(orchestrator.activeSheetItem?.id, "celebration")
        XCTAssertFalse(flowCompleted)
        
        // Dismiss sheet using programmatic dismissCurrentAction
        orchestrator.dismissCurrentAction()
        
        let exp = expectation(description: "Flow completion callback")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            XCTAssertEqual(executionOrder, ["ad"])
            XCTAssertTrue(flowCompleted, "onFlowComplete callback must be invoked when all actions finish.")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }
}
