//
//  PaywallPacingEngine.swift
//  GraceAppsLibrary
//
//  Created by Grace Huang on 11/11/26.
//

import Foundation

/// Trigger category classification for paywall presentation decisions.
public enum PaywallTriggerCategory: String, Sendable, CaseIterable {
    /// Direct user intent (e.g. tapping "Go Pro" or a locked Pro feature). Always approved.
    case directIntent = "direct_intent"
    /// User reached a free usage threshold (e.g. 5 free bookmarks). Approved to unlock unlimited access.
    case endowmentThreshold = "endowment_threshold"
    /// Milestone moment (e.g. activity/deck/quiz completed). Paced and throttled to prevent spam.
    case milestoneAchievement = "milestone_achievement"
}

/// Configuration governing milestone paywall throttling and session capping.
public struct PaywallPacingConfig: Sendable {
    /// Number of activity completions required before re-triggering a milestone paywall (default: 3).
    public var milestoneCompletionInterval: Int
    /// Time interval before re-triggering a milestone paywall regardless of completion count (default: 7 days).
    public var milestoneDayInterval: TimeInterval
    /// Whether milestone paywalls are capped to at most once per session (default: true).
    public var isSessionCapEnabled: Bool
    
    public init(
        milestoneCompletionInterval: Int = 3,
        milestoneDayInterval: TimeInterval = 7 * 24 * 60 * 60,
        isSessionCapEnabled: Bool = true
    ) {
        self.milestoneCompletionInterval = milestoneCompletionInterval
        self.milestoneDayInterval = milestoneDayInterval
        self.isSessionCapEnabled = isSessionCapEnabled
    }
}

/// Analytics statistics for a specific paywall trigger.
public struct PaywallTriggerStats: Sendable {
    public let shown: Int
    public let purchased: Int
    public let dismissed: Int
    
    public init(shown: Int, purchased: Int, dismissed: Int) {
        self.shown = shown
        self.purchased = purchased
        self.dismissed = dismissed
    }
}

/// Central engine managing commercial conversion policy, milestone throttling, and paywall pacing.
@MainActor
public final class PaywallPacingEngine {
    public static let shared = PaywallPacingEngine()
    
    // MARK: - Configuration
    
    public var config = PaywallPacingConfig()
    
    /// Closure returning whether the current user has an active Pro subscription or entitlement.
    public var isProUser: () -> Bool = { false }
    
    // MARK: - Storage Keys
    
    private struct StorageKeys {
        static let completionsCountKey = "GraceApps_Paywall_MilestoneCompletionsCount"
        static let lastOfferDateKey = "GraceApps_Paywall_MilestoneLastOfferDate"
        static let statsShownPrefix = "GraceApps_Paywall_Stats_Shown_"
        static let statsPurchasedPrefix = "GraceApps_Paywall_Stats_Purchased_"
        static let statsDismissedPrefix = "GraceApps_Paywall_Stats_Dismissed_"
    }
    
    // MARK: - Session State
    
    /// Whether a milestone paywall has already been presented during this app session.
    public private(set) var hasShownMilestoneThisSession: Bool = false
    
    public init() {}
    
    // MARK: - Session & Activity Lifecycle
    
    /// Resets session-level flags. Call on app background or session start.
    public func resetSession() {
        hasShownMilestoneThisSession = false
        GraceLogger.orchestrator("PaywallPacingEngine: Session reset.", level: .info)
    }
    
    /// Records a completed study/practice/quiz activity.
    public func recordActivityCompletion() {
        let current = UserDefaults.standard.integer(forKey: StorageKeys.completionsCountKey)
        UserDefaults.standard.set(current + 1, forKey: StorageKeys.completionsCountKey)
        GraceLogger.orchestrator("PaywallPacingEngine: Activity completion recorded (total: \(current + 1)).", level: .info)
    }
    
    /// Records that a milestone offer was presented to the user, restarting the throttling interval.
    public func recordMilestoneOfferPresented() {
        UserDefaults.standard.set(0, forKey: StorageKeys.completionsCountKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: StorageKeys.lastOfferDateKey)
        hasShownMilestoneThisSession = true
        GraceLogger.orchestrator("PaywallPacingEngine: Milestone offer presented. Throttling clock reset.", level: .info)
    }
    
    // MARK: - Eligibility Evaluation
    
    /// Evaluates whether a paywall presentation should be approved based on category and pacing policy.
    public func canPresentPaywall(category: PaywallTriggerCategory) -> Bool {
        guard !isProUser() else {
            GraceLogger.orchestrator("Paywall presentation suppressed: User is already Pro.", level: .info)
            return false
        }
        
        switch category {
        case .directIntent:
            GraceLogger.orchestrator("Paywall presentation approved: Direct user intent.", level: .info)
            return true
            
        case .endowmentThreshold:
            GraceLogger.orchestrator("Paywall presentation approved: Endowment threshold reached.", level: .info)
            return true
            
        case .milestoneAchievement:
            let eligible = shouldPromptMilestone()
            if eligible {
                GraceLogger.orchestrator("Paywall presentation approved: Milestone achievement eligible.", level: .info)
            } else {
                GraceLogger.orchestrator("Paywall presentation throttled: Milestone achievement policy.", level: .info)
            }
            return eligible
        }
    }
    
    private func shouldPromptMilestone() -> Bool {
        if config.isSessionCapEnabled && hasShownMilestoneThisSession {
            return false
        }
        
        let completions = UserDefaults.standard.integer(forKey: StorageKeys.completionsCountKey)
        let lastDateTimestamp = UserDefaults.standard.double(forKey: StorageKeys.lastOfferDateKey)
        
        // First completion ever
        if lastDateTimestamp == 0 {
            return true
        }
        
        // Re-eligible after completion count interval
        if completions >= config.milestoneCompletionInterval {
            return true
        }
        
        // Re-eligible after time interval
        let daysPassed = Date().timeIntervalSince1970 - lastDateTimestamp
        if daysPassed >= config.milestoneDayInterval {
            return true
        }
        
        return false
    }
    
    // MARK: - Analytics Stats Tracking
    
    public func recordTriggerShown(_ triggerId: String) {
        let key = StorageKeys.statsShownPrefix + triggerId
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: key) + 1, forKey: key)
    }
    
    public func recordTriggerPurchased(_ triggerId: String) {
        let key = StorageKeys.statsPurchasedPrefix + triggerId
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: key) + 1, forKey: key)
    }
    
    public func recordTriggerDismissed(_ triggerId: String) {
        let key = StorageKeys.statsDismissedPrefix + triggerId
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: key) + 1, forKey: key)
    }
    
    public func getTriggerStats(for triggerId: String) -> PaywallTriggerStats {
        PaywallTriggerStats(
            shown: UserDefaults.standard.integer(forKey: StorageKeys.statsShownPrefix + triggerId),
            purchased: UserDefaults.standard.integer(forKey: StorageKeys.statsPurchasedPrefix + triggerId),
            dismissed: UserDefaults.standard.integer(forKey: StorageKeys.statsDismissedPrefix + triggerId)
        )
    }
    
    // MARK: - Testing Helpers
    
    public func resetForTesting() {
        hasShownMilestoneThisSession = false
        isProUser = { false }
        config = PaywallPacingConfig()
        UserDefaults.standard.removeObject(forKey: StorageKeys.completionsCountKey)
        UserDefaults.standard.removeObject(forKey: StorageKeys.lastOfferDateKey)
    }
}
