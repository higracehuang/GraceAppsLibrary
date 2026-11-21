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

    func testSkippedActionDoesNotTriggerMutualExclusion() {
        let orchestrator = UXFlowOrchestrator.shared
        orchestrator.policy.mutuallyExclude(triggerTag: "review", suppressTag: "ad")
        
        var adPresented = false
        
        let reviewAction = UXAction(id: "review", priority: .review, kind: .customAsync, tags: ["review"]) { completion in
            // Simulated skipped review (e.g. checkpoint not reached)
            completion(.skipped)
        }
        
        let adAction = UXAction(id: "ad", priority: .ad, kind: .customAsync, tags: ["ad"]) { completion in
            adPresented = true
            completion(.completed)
        }
        
        orchestrator.triggerFlow(actions: [reviewAction, adAction])
        
        let exp = expectation(description: "Wait for pipeline")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            XCTAssertTrue(adPresented, "Ad should be presented because review was skipped.")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    func testMutualExclusionDoesNotLeakAcrossDifferentFlows() {
        let orchestrator = UXFlowOrchestrator.shared
        orchestrator.policy.mutuallyExclude(triggerTag: "review", suppressTag: "ad")

        var reviewPresented = false
        var adPresentedInSecondFlow = false

        let reviewAction = UXAction(id: "review", priority: .review, kind: .customAsync, tags: ["review"]) { completion in
            reviewPresented = true
            completion(.completed)
        }

        // Flow 1: review executes
        orchestrator.triggerFlow(actions: [reviewAction])
        XCTAssertTrue(reviewPresented)

        // Wait for Flow 1 settling, then trigger Flow 2: ad must execute
        let exp = expectation(description: "Flow 1 settles and Flow 2 triggers")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let adAction = UXAction(id: "ad", priority: .ad, kind: .customAsync, tags: ["ad"]) { completion in
                adPresentedInSecondFlow = true
                completion(.completed)
            }

            orchestrator.triggerFlow(actions: [adAction])
            XCTAssertTrue(adPresentedInSecondFlow, "Ad in a subsequent flow must NOT be suppressed by completed previous flow.")
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertEqual(executionOrder, ["ad"])
            XCTAssertTrue(flowCompleted, "onFlowComplete callback must be invoked when all actions finish.")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    func testRatingPromptFactoryAction() {
        var promptCalled = false
        let ratingAction = UXAction.ratingPrompt {
            promptCalled = true
            return true
        }

        XCTAssertEqual(ratingAction.id, "rating_prompt")
        XCTAssertEqual(ratingAction.priority, .review)
        XCTAssertTrue(ratingAction.tags.contains("review"))

        let orchestrator = UXFlowOrchestrator.shared
        orchestrator.triggerFlow(actions: [ratingAction])
        XCTAssertTrue(promptCalled)
    }

    func testRequestCompletionFlowConvenience() {
        let orchestrator = UXFlowOrchestrator.shared
        var flowCompleted = false
        var adExecuted = false

        let milestone = UXAction(id: "results", priority: .milestone, kind: .sheet) {
            Text("Done")
        }
        let ad = UXAction(id: "ad", priority: .ad, kind: .customAsync) { completion in
            adExecuted = true
            completion(.completed)
        }

        orchestrator.requestCompletionFlow(
            milestoneSheet: milestone,
            reviewAction: nil,
            adAction: ad
        ) {
            flowCompleted = true
        }

        XCTAssertEqual(orchestrator.activeSheetItem?.id, "results")
        orchestrator.dismissCurrentAction()

        let exp = expectation(description: "Completion flow finishes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            XCTAssertTrue(adExecuted)
            XCTAssertTrue(flowCompleted)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    func testCancelFlowAndDismissCancelsRemainingActions() {
        let orchestrator = UXFlowOrchestrator.shared
        var adExecuted = false
        var flowCompleted = false

        let milestone = UXAction.milestone(id: "results") {
            Text("Celebration")
        }
        let ad = UXAction.ad(id: "post_ad") { completion in
            adExecuted = true
            completion(true)
        }

        orchestrator.requestCompletionFlow(
            milestoneSheet: milestone,
            adAction: ad
        ) {
            flowCompleted = true
        }

        XCTAssertEqual(orchestrator.activeSheetItem?.id, "results")

        // User hits "Practice Again" or "Retry Quiz" -> cancel flow & dismiss
        orchestrator.cancelFlowAndDismiss()

        XCTAssertNil(orchestrator.activeSheetItem)

        let exp = expectation(description: "Ensure ad and completion callback never run")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            XCTAssertFalse(adExecuted, "Trailing ad must NOT run after flow is cancelled.")
            XCTAssertFalse(flowCompleted, "Completion callback must NOT fire after cancellation.")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    func testStandardPolicyEnforcement() {
        let policy = UXPolicy.standard
        XCTAssertTrue(policy.mutualExclusions[.review]?.contains(.ad) == true)
        XCTAssertTrue(policy.mutualExclusions[.paywall]?.contains(.ad) == true)
        XCTAssertTrue(policy.mutualExclusions[.releaseNotes]?.contains(.ad) == true)
        XCTAssertTrue(policy.mutualExclusions[.releaseNotes]?.contains(.review) == true)
        XCTAssertEqual(policy.sessionCaps[.releaseNotes], 1)
        XCTAssertEqual(policy.tagCooldowns[.ad], 20)
    }

    func testStandardActionFactories() {
        let milestone = UXAction.milestone { Text("Done") }
        XCTAssertEqual(milestone.id, "milestone_sheet")
        XCTAssertEqual(milestone.priority, .milestone)
        XCTAssertEqual(milestone.kind, .sheet)
        XCTAssertTrue(milestone.tags.contains(.celebration))

        var adPresented = false
        let adAction = UXAction.ad { completion in
            adPresented = true
            completion(true)
        }
        XCTAssertEqual(adAction.id, "interstitial_ad")
        XCTAssertEqual(adAction.priority, .ad)
        XCTAssertEqual(adAction.kind, .customAsync)
        XCTAssertTrue(adAction.tags.contains(.ad))

        let orchestrator = UXFlowOrchestrator.shared
        orchestrator.triggerFlow(actions: [adAction])
        XCTAssertTrue(adPresented)
    }
    
    func testResetFlowStateWhileBusyCancelsAndDismisses() {
        let orchestrator = UXFlowOrchestrator.shared
        let action1 = UXAction(id: "sheet_1", priority: .milestone, kind: .sheet) {
            Text("Sheet 1")
        }
        let action2 = UXAction(id: "sheet_2", priority: .ad, kind: .sheet) {
            Text("Sheet 2")
        }
        
        orchestrator.triggerFlow(actions: [action1, action2])
        XCTAssertNotNil(orchestrator.activeSheetItem)
        XCTAssertEqual(orchestrator.activeSheetItem?.id, "sheet_1")
        XCTAssertTrue(orchestrator.isBusy)
        
        // Calling resetFlowState while busy should self-heal by dismissing the active modal and cancelling queued actions
        orchestrator.resetFlowState()
        XCTAssertNil(orchestrator.activeSheetItem)
        
        let expectation = expectation(description: "Wait for settling window to finish")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            XCTAssertFalse(orchestrator.isBusy)
            XCTAssertNil(orchestrator.activeSheetItem)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
    }
    
    func testInterPresentationDelayClamping() {
        let orchestrator = UXFlowOrchestrator.shared
        orchestrator.interPresentationDelay = -1.0
        XCTAssertEqual(orchestrator.interPresentationDelay, 0.01)
        
        orchestrator.interPresentationDelay = 0.0
        XCTAssertEqual(orchestrator.interPresentationDelay, 0.01)
        
        orchestrator.interPresentationDelay = 0.5
        XCTAssertEqual(orchestrator.interPresentationDelay, 0.5)
    }

    func testUXActionIDConstantsAndPolicyIntegration() {
        XCTAssertEqual(UXActionID.interstitialAd.rawValue, "interstitial_ad")
        XCTAssertEqual(UXActionID.ratingPrompt.rawValue, "rating_prompt")
        XCTAssertEqual(UXActionID.milestoneSheet.rawValue, "milestone_sheet")
        XCTAssertEqual(UXActionID.paywall.rawValue, "paywall")
        XCTAssertEqual(UXActionID.releaseNotes.rawValue, "release_notes")
        XCTAssertEqual(UXActionID.celebration.rawValue, "milestone_sheet")
        XCTAssertEqual(UXTag.releaseNotes.rawValue, "release_notes")
        XCTAssertEqual(UXActionPriority.releaseNotes.rawValue, 600)
        XCTAssertTrue(UXActionPriority.milestone > UXActionPriority.releaseNotes)
        XCTAssertTrue(UXActionPriority.releaseNotes > UXActionPriority.paywall)
        XCTAssertTrue(UXActionPriority.paywall > UXActionPriority.review)
        XCTAssertTrue(UXActionPriority.review > UXActionPriority.ad)

        var policy = UXPolicy()
        policy.setSessionCap(actionId: .interstitialAd, maxCount: 2)
        XCTAssertEqual(policy.sessionCaps[.interstitialAd], 2)

        var conditionMet = false
        policy.setPrecondition(actionId: .interstitialAd) { conditionMet }
        XCTAssertFalse(policy.preconditions[.interstitialAd]?() ?? true)
        conditionMet = true
        XCTAssertTrue(policy.preconditions[.interstitialAd]?() ?? false)

        let adAction = UXAction.ad(id: .interstitialAd) { completion in
            completion(true)
        }
        XCTAssertEqual(adAction.id, .interstitialAd)
    }

    func testDismissCurrentActionWithOnSettledCallback() {
        let orchestrator = UXFlowOrchestrator.shared
        orchestrator.resetForTesting()
        orchestrator.interPresentationDelay = 0.02

        let sheetAction = UXAction(id: .releaseNotes, priority: .releaseNotes, kind: .sheet) {
            Text("Release Notes")
        }
        orchestrator.requestAction(sheetAction)
        XCTAssertEqual(orchestrator.activeSheetItem?.id, .releaseNotes)
        XCTAssertTrue(orchestrator.isBusy)

        var settledFired = false
        var wasBusyWhenSettled = true
        let exp = expectation(description: "Wait for onSettled callback")

        orchestrator.dismissCurrentAction {
            settledFired = true
            wasBusyWhenSettled = orchestrator.isBusy
            exp.fulfill()
        }

        // Immediately after dismissCurrentAction, activeSheetItem is nil, but onSettled has not fired yet
        XCTAssertNil(orchestrator.activeSheetItem)
        XCTAssertFalse(settledFired)

        wait(for: [exp], timeout: 1.0)
        XCTAssertTrue(settledFired)
        XCTAssertFalse(wasBusyWhenSettled, "onSettled must execute after settling window when orchestrator is no longer busy")
    }

    func testAsyncEnqueuedActionResortsQueueByPriorityWhileBusy() {
        let orchestrator = UXFlowOrchestrator.shared
        orchestrator.resetForTesting()
        orchestrator.interPresentationDelay = 0.01

        let firstSheet = UXAction(id: .releaseNotes, priority: .releaseNotes, kind: .sheet) {
            Text("First")
        }
        let lowPrioritySheet = UXAction(id: "low_priority", priority: .ad, kind: .sheet) {
            Text("Low")
        }
        let midPrioritySheet = UXAction(id: "mid_priority", priority: UXActionPriority(rawValue: 550), kind: .sheet) {
            Text("Mid")
        }

        // Start flow with 600 and 100 -> 600 presents, 100 is in queue
        orchestrator.requestActions([firstSheet, lowPrioritySheet])
        XCTAssertEqual(orchestrator.activeSheetItem?.id, .releaseNotes)

        // While 600 is active, 550 arrives asynchronously -> must sort ahead of 100 in the queue
        orchestrator.requestAction(midPrioritySheet)

        orchestrator.dismissCurrentAction()
        let exp1 = expectation(description: "Wait for mid_priority")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
            XCTAssertEqual(orchestrator.activeSheetItem?.id, "mid_priority", "Mid-priority (550) must present before low-priority (100)")
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: 1.0)
    }

    func testCancelFlowAndDismissWithOnSettledDropsQueuedActionsAndFiresSettledCallback() {
        let orchestrator = UXFlowOrchestrator.shared
        orchestrator.resetForTesting()
        orchestrator.interPresentationDelay = 0.02

        let releaseNotesSheet = UXAction(id: .releaseNotes, priority: .releaseNotes, kind: .sheet) {
            Text("Release Notes")
        }
        let queuedCycleSyncSheet = UXAction(id: "cycle_sync_preview", priority: UXActionPriority(rawValue: 550), kind: .sheet) {
            Text("Cycle Sync")
        }

        orchestrator.requestActions([releaseNotesSheet, queuedCycleSyncSheet])
        XCTAssertEqual(orchestrator.activeSheetItem?.id, .releaseNotes)

        var paywallUpgradeTriggered = false
        let exp = expectation(description: "Wait for settled upgrade callback")
        orchestrator.cancelFlowAndDismiss {
            paywallUpgradeTriggered = true
            exp.fulfill()
        }

        XCTAssertNil(orchestrator.activeSheetItem)
        XCTAssertFalse(paywallUpgradeTriggered)

        wait(for: [exp], timeout: 1.0)
        XCTAssertTrue(paywallUpgradeTriggered)
        XCTAssertNil(orchestrator.activeSheetItem, "Queued cycle_sync_preview must be cancelled so paywall opens without competition")
        XCTAssertFalse(orchestrator.isBusy)
    }

    func testActionIDDeduplicationInQueueAndWhileActive() {
        let orchestrator = UXFlowOrchestrator.shared
        orchestrator.resetForTesting()
        orchestrator.interPresentationDelay = 0.01

        let releaseNotesSheet = UXAction(id: .releaseNotes, priority: .releaseNotes, kind: .sheet) {
            Text("Release Notes")
        }
        let autoCycleSync = UXAction(id: "cycle_sync_preview", priority: UXActionPriority(rawValue: 550), kind: .sheet) {
            Text("Auto Sync")
        }
        let manualCycleSync = UXAction(id: "cycle_sync_preview", priority: .critical, kind: .sheet) {
            Text("Manual Sync")
        }

        // 1. Present Release Notes (600) and queue Auto Cycle Sync (550)
        orchestrator.requestActions([releaseNotesSheet, autoCycleSync])
        XCTAssertEqual(orchestrator.activeSheetItem?.id, .releaseNotes)

        // 2. Requesting releaseNotesSheet again while it is active on screen must be rejected
        orchestrator.requestAction(releaseNotesSheet)
        XCTAssertEqual(orchestrator.activeSheetItem?.id, .releaseNotes)

        // 3. Requesting manualCycleSync (1000) with same ID "cycle_sync_preview" while queued must replace the existing queued entry rather than stacking two copies
        orchestrator.requestAction(manualCycleSync)

        // 4. Dismiss Release Notes -> Cycle Sync presents once with updated priority (1000), then queue is empty
        orchestrator.dismissCurrentAction()
        let exp1 = expectation(description: "Wait for deduplicated cycle_sync_preview")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            XCTAssertEqual(orchestrator.activeSheetItem?.id, "cycle_sync_preview")
            XCTAssertEqual(orchestrator.activeSheetItem?.action.priority, .critical)
            orchestrator.dismissCurrentAction()
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: 1.0)

        let exp2 = expectation(description: "Verify no duplicate cycle_sync_preview presents")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            XCTAssertNil(orchestrator.activeSheetItem, "Deduplicated queue must not present a second copy of cycle_sync_preview")
            XCTAssertFalse(orchestrator.isBusy)
            exp2.fulfill()
        }
        wait(for: [exp2], timeout: 1.0)
    }

    func testActionPreconditionFiltersIneligibleSheetAndRunsTrailingAd() {
        let orchestrator = UXFlowOrchestrator.shared
        orchestrator.resetForTesting()
        orchestrator.interPresentationDelay = 0.01

        var shouldShowSheet = false
        var adPresentedCount = 0

        let makeActions: () -> [UXAction] = {
            [
                UXAction(
                    id: "conditional_prompt",
                    priority: .critical,
                    kind: .sheet,
                    precondition: { shouldShowSheet }
                ) {
                    Text("Conditional Prompt")
                },
                UXAction.ad { completion in
                    adPresentedCount += 1
                    completion(true)
                }
            ]
        }

        // 1. Precondition false -> sheet is skipped, ad presents immediately
        orchestrator.requestActions(makeActions())
        XCTAssertNil(orchestrator.activeSheetItem)
        XCTAssertEqual(adPresentedCount, 1, "Ad must execute immediately when conditional sheet precondition is false")

        let settleExp = expectation(description: "Wait for pipeline idle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            XCTAssertFalse(orchestrator.isBusy)
            settleExp.fulfill()
        }
        wait(for: [settleExp], timeout: 1.0)

        // 2. Precondition true -> sheet presents first, ad executes only after dismissal
        shouldShowSheet = true
        orchestrator.requestActions(makeActions())
        XCTAssertEqual(orchestrator.activeSheetItem?.id, "conditional_prompt")
        XCTAssertEqual(adPresentedCount, 1, "Ad must wait while conditional sheet is active")

        orchestrator.dismissCurrentAction()
        let adExp = expectation(description: "Wait for trailing ad after sheet dismissal")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            XCTAssertEqual(adPresentedCount, 2, "Trailing ad must execute after conditional sheet dismisses")
            adExp.fulfill()
        }
        wait(for: [adExp], timeout: 1.0)
    }

    func testStandardPolicyPaywallSuppressesReviewPrompt() {
        ReviewPromptManager.debugResetReviewState()
        let orchestrator = UXFlowOrchestrator.shared
        orchestrator.policy = .standard

        XCTAssertTrue(ReviewPromptManager.shared.isEligibleForPrompt(), "Precondition must be true so mutual exclusion is exercised")

        var paywallPresented = false
        var reviewPrompted = false

        let paywallAction = UXAction(
            id: .paywall,
            priority: .paywall,
            kind: .customAsync,
            tags: [.paywall]
        ) { completion in
            paywallPresented = true
            completion(.completed)
        }
        let reviewAction = UXAction.ratingPrompt {
            reviewPrompted = true
            return true
        }

        orchestrator.triggerFlow(actions: [paywallAction, reviewAction])

        XCTAssertTrue(paywallPresented)
        let exp = expectation(description: "Wait for flow settling")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            XCTAssertFalse(reviewPrompted, "UXPolicy.standard must suppress review prompts after a paywall in the same flow")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    func testStandardPolicyAdSuppressesReviewPrompt() {
        ReviewPromptManager.debugResetReviewState()
        let orchestrator = UXFlowOrchestrator.shared
        orchestrator.policy = .standard

        XCTAssertTrue(ReviewPromptManager.shared.isEligibleForPrompt(), "Precondition must be true so mutual exclusion is exercised")

        var adPresented = false
        var reviewPrompted = false

        // Give the ad higher priority than review to verify symmetric .ad -> .review exclusion
        let adAction = UXAction(
            id: .interstitialAd,
            priority: UXActionPriority(rawValue: 300),
            kind: .customAsync,
            tags: [.ad]
        ) { completion in
            adPresented = true
            completion(.completed)
        }
        let reviewAction = UXAction.ratingPrompt {
            reviewPrompted = true
            return true
        }

        orchestrator.triggerFlow(actions: [adAction, reviewAction])

        XCTAssertTrue(adPresented)
        let exp = expectation(description: "Wait for flow settling")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            XCTAssertFalse(reviewPrompted, "UXPolicy.standard must suppress review prompts after an ad in the same flow")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }
}
