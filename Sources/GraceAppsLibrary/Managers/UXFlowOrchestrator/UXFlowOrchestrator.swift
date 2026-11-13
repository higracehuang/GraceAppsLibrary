//
//  UXFlowOrchestrator.swift
//  GraceAppsLibrary
//
//  Created by Grace Huang on 11/11/26.
//

import SwiftUI
import Combine

/// Action-agnostic presentation orchestrator that sequences sheets, covers, alerts, and ads.
/// Enforces single-slot presentation and inter-presentation settling delays to eliminate modal collisions and cancellations.
@MainActor
public final class UXFlowOrchestrator: ObservableObject {
    public static let shared = UXFlowOrchestrator()
    
    // MARK: - Published State
    
    /// The active sheet item bound to SwiftUI's `.sheet(item:)` modifier.
    @Published public private(set) var activeSheetItem: UXActionItem?
    
    /// The active fullScreenCover item bound to SwiftUI's `.fullScreenCover(item:)` modifier.
    @Published public private(set) var activeCoverItem: UXActionItem?
    
    /// Indicates whether a modal is currently presenting or transitioning.
    @Published public private(set) var isBusy: Bool = false
    
    /// The identifier of the action currently active on screen.
    @Published public private(set) var currentActionId: UXActionID?
    
    /// Indicates whether a view modifier host (`scopedUXFlow`) is actively mounted.
    @Published public internal(set) var isHostMounted: Bool = false
    
    // MARK: - Configuration
    
    /// Declarative policy rules governing priorities, cooldowns, and exclusions.
    public var policy = UXPolicy()
    
    /// Delay between consecutive presentations allowing UIKit dismiss animations to complete (default: 0.45s).
    public var interPresentationDelay: TimeInterval = 0.45 {
        didSet {
            if interPresentationDelay < 0.01 {
                interPresentationDelay = 0.01
            }
        }
    }
    
    // MARK: - Internal State
    
    private var actionQueue: [UXAction] = []
    private var sessionActionCounts: [UXActionID: Int] = [:]
    private var lastPresentedTimes: [UXTag: Date] = [:]
    private var executedTagsThisFlow: Set<UXTag> = []
    private var flowCompletionCallback: (() -> Void)?
    
    internal init() {}
    
    // MARK: - Flow Execution
    
    /// Evaluates candidate actions, sorts them by priority, and begins serial execution.
    /// - Parameters:
    ///   - actions: Array of candidate actions eligible at this trigger point.
    ///   - onFlowComplete: Optional callback executed when all actions in this flow have finished.
    public func triggerFlow(actions: [UXAction], onFlowComplete: (() -> Void)? = nil) {
        #if DEBUG
        if !isHostMounted && actions.contains(where: { $0.kind == .sheet || $0.kind == .fullScreenCover }) {
            GraceLogger.orchestrator("⚠️ Warning: Triggered modal actions without an active host. Ensure .scopedUXFlow() or .withUXFlowOrchestrator() is attached to your view hierarchy.", level: .warning)
        }
        #endif
        
        self.flowCompletionCallback = onFlowComplete
        GraceLogger.orchestrator("Triggering flow with \(actions.count) candidate actions: \(actions.map { $0.id })", level: .info)
        
        let eligible = actions
            .filter { evaluateEligibility(for: $0) }
            .sorted(by: { $0.priority > $1.priority })
        
        guard !eligible.isEmpty else {
            GraceLogger.orchestrator("No candidate actions passed policy eligibility check.", level: .info)
            let callback = flowCompletionCallback
            self.flowCompletionCallback = nil
            callback?()
            return
        }
        
        GraceLogger.orchestrator("Enqueued \(eligible.count) approved actions in priority order: \(eligible.map { "\($0.id)(\($0.priority.rawValue))" })", level: .success)
        actionQueue.append(contentsOf: eligible)
        processNextInQueue()
    }
    
    /// Convenience alias for triggerFlow.
    public func requestActions(_ actions: [UXAction], onFlowComplete: (() -> Void)? = nil) {
        triggerFlow(actions: actions, onFlowComplete: onFlowComplete)
    }
    
    /// Convenience method to request a single action.
    public func requestAction(_ action: UXAction, onFlowComplete: (() -> Void)? = nil) {
        triggerFlow(actions: [action], onFlowComplete: onFlowComplete)
    }
    
    /// Programmatically dismisses the active visual modal (sheet or cover) and transitions to the next queued action.
    public func dismissCurrentAction() {
        if let sheet = activeSheetItem {
            onModalDismissed(actionId: sheet.id)
        } else if let cover = activeCoverItem {
            onModalDismissed(actionId: cover.id)
        }
    }
    
    /// Atomically cancels all pending actions in the current flow and dismisses the currently active modal.
    /// Use this when the user chooses an action that terminates the sequence (e.g. "Practice Again" or "Review Mistakes").
    public func cancelFlowAndDismiss() {
        actionQueue.removeAll()
        flowCompletionCallback = nil
        dismissCurrentAction()
    }
    
    /// Cancels any remaining queued actions in this flow without dismissing the currently active modal.
    public func cancelRemainingActions() {
        actionQueue.removeAll()
        flowCompletionCallback = nil
    }
    
    /// Processes the next item in the prioritized queue.
    private func processNextInQueue() {
        guard !isBusy else {
            GraceLogger.orchestrator("Pipeline busy (action: '\(currentActionId ?? "none")'). Next action will wait in queue.", level: .info)
            return
        }
        
        guard !actionQueue.isEmpty else {
            isBusy = false
            currentActionId = nil
            GraceLogger.orchestrator("Presentation queue completed. Pipeline idle.", level: .info)
            let callback = flowCompletionCallback
            flowCompletionCallback = nil
            callback?()
            return
        }
        
        let nextAction = actionQueue.removeFirst()
        
        // Check mutual exclusion against tags already displayed in this flow
        guard evaluateFlowMutualExclusion(for: nextAction) else {
            GraceLogger.orchestrator("Action '\(nextAction.id)' dropped due to flow mutual exclusion with executed tags: \(executedTagsThisFlow)", level: .warning)
            processNextInQueue()
            return
        }
        
        isBusy = true
        currentActionId = nextAction.id
        recordActionStart(nextAction)
        
        GraceLogger.orchestrator("Presenting '\(nextAction.id)' (kind: \(nextAction.kind), priority: \(nextAction.priority.rawValue))...", level: .success)
        
        switch nextAction.kind {
        case .sheet:
            activeSheetItem = UXActionItem(action: nextAction)
            
        case .fullScreenCover:
            activeCoverItem = UXActionItem(action: nextAction)
            
        case .systemDialog, .customAsync:
            nextAction.executionBlock? { [weak self] outcome in
                guard let self = self else { return }
                GraceLogger.orchestrator("Custom/System action '\(nextAction.id)' completed with outcome: \(outcome)", level: .info)
                self.completeAction(nextAction)
            }
        }
    }
    
    /// Handles dismissal of visual sheets and full-screen covers.
    /// Intercepted by `UXFlowViewModifier` to guarantee clean transitions.
    internal func onModalDismissed(actionId: UXActionID) {
        guard let current = (activeSheetItem?.action ?? activeCoverItem?.action), current.id == actionId else {
            GraceLogger.orchestrator("Received onModalDismissed for '\(actionId)' but active item was different.", level: .warning)
            return
        }
        
        activeSheetItem = nil
        activeCoverItem = nil
        GraceLogger.orchestrator("Visual modal '\(actionId)' dismissed. Entering \(interPresentationDelay)s settling window...", level: .info)
        completeAction(current)
    }

    /// Backward-compatible overload for string action IDs.
    internal func onModalDismissed(actionId: String) {
        onModalDismissed(actionId: UXActionID(actionId))
    }
    
    private func completeAction(_ action: UXAction) {
        // Enforce settling window so the UIKit transition completes cleanly before next modal mounts
        DispatchQueue.main.asyncAfter(deadline: .now() + interPresentationDelay) { [weak self] in
            guard let self = self else { return }
            self.isBusy = false
            self.currentActionId = nil
            self.processNextInQueue()
        }
    }
    
    /// Resets tags executed in the current flow. Call when starting a new activity or screen.
    public func resetFlowState() {
        if isBusy {
            GraceLogger.orchestrator("⚠️ Warning: resetFlowState() called while a presentation is active. Automatically invoking cancelFlowAndDismiss().", level: .warning)
            cancelFlowAndDismiss()
            return
        }
        executedTagsThisFlow.removeAll()
        actionQueue.removeAll()
        flowCompletionCallback = nil
        GraceLogger.orchestrator("Flow state reset.", level: .info)
    }
    
    // MARK: - Policy Filtering
    
    private func evaluateEligibility(for action: UXAction) -> Bool {
        // 1. App-level precondition
        if let precondition = policy.preconditions[action.id], !precondition() {
            GraceLogger.orchestrator("Action '\(action.id)' rejected: Precondition returned false.", level: .info)
            return false
        }
        
        // 2. Session cap
        if let cap = policy.sessionCaps[action.id] {
            let count = sessionActionCounts[action.id] ?? 0
            if count >= cap {
                GraceLogger.orchestrator("Action '\(action.id)' rejected: Session cap reached (\(count)/\(cap)).", level: .info)
                return false
            }
        }
        
        // 3. Tag cooldowns
        for tag in action.tags {
            if let cooldown = policy.tagCooldowns[tag],
               let lastTime = lastPresentedTimes[tag] {
                let elapsed = Date().timeIntervalSince(lastTime)
                if elapsed < cooldown {
                    GraceLogger.orchestrator("Action '\(action.id)' rejected: Tag '\(tag)' cooldown active (\(Int(elapsed))s < \(Int(cooldown))s).", level: .info)
                    return false
                }
            }
        }
        
        return true
    }
    
    private func evaluateFlowMutualExclusion(for action: UXAction) -> Bool {
        for executedTag in executedTagsThisFlow {
            if let excluded = policy.mutualExclusions[executedTag], !action.tags.isDisjoint(with: excluded) {
                return false
            }
        }
        return true
    }
    
    private func recordActionStart(_ action: UXAction) {
        sessionActionCounts[action.id, default: 0] += 1
        let now = Date()
        for tag in action.tags {
            lastPresentedTimes[tag] = now
            executedTagsThisFlow.insert(tag)
        }
    }
    
    // MARK: - Testing Helpers
    
    public func resetForTesting() {
        activeSheetItem = nil
        activeCoverItem = nil
        isBusy = false
        currentActionId = nil
        isHostMounted = false
        actionQueue.removeAll()
        sessionActionCounts.removeAll()
        lastPresentedTimes.removeAll()
        executedTagsThisFlow.removeAll()
        flowCompletionCallback = nil
        policy = UXPolicy()
        interPresentationDelay = 0.35
    }
}

// MARK: - Completion Flow Orchestration

extension UXFlowOrchestrator {
    /// Requests a structured activity completion flow combining celebration/milestone,
    /// review prompt, and ad actions in accordance with priority policy.
    public func requestCompletionFlow(
        milestoneSheet: UXAction,
        reviewAction: UXAction? = nil,
        adAction: UXAction? = nil,
        onFlowComplete: (() -> Void)? = nil
    ) {
        var actions: [UXAction] = [milestoneSheet]
        if let reviewAction = reviewAction {
            actions.append(reviewAction)
        }
        if let adAction = adAction {
            actions.append(adAction)
        }
        requestActions(actions, onFlowComplete: onFlowComplete)
    }
}
