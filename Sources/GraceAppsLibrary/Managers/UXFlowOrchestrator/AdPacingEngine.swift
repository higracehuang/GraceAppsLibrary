//
//  AdPacingEngine.swift
//  GraceAppsLibrary
//
//  Created by Grace Huang on 11/11/26.
//

import Foundation

/// Pacing and frequency configuration for full-screen interstitial and rewarded ads.
public struct AdPacingConfig {
    /// Minimum time in seconds required between any two ad presentations.
    public var safetyDebounce: TimeInterval = 20.0
    /// Minimum cooldown in seconds for a specific ad trigger.
    public var triggerCooldown: TimeInterval = 120.0
    /// Maximum lifespan of a cached ad before it must be evicted (AdMob ads expire in 1 hour; default: 50 mins).
    public var cacheTTL: TimeInterval = 50 * 60
    /// Maximum number of ad impressions permitted within a single app session.
    public var maxPerSession: Int = 4
    /// When true, skips ads on the user's very first launch/session to protect initial onboarding.
    public var isFirstRunExempt: Bool = true
    
    public init() {}
}

/// Central policy and pacing gatekeeper for ads across all apps.
/// Decoupled from GoogleMobileAds; governs all decisions before network requests or presentations.
@MainActor
public final class AdPacingEngine: ObservableObject {
    public static let shared = AdPacingEngine()
    
    private struct StorageKeys {
        static let hasCompletedFirstRunAdExemptionKey = "GraceAppsLibrary_AdPacing_FirstRunExempt"
    }
    
    public var config = AdPacingConfig()
    
    /// Closure providing the client app's Pro / Ad-Free entitlement status.
    public var isProUser: () -> Bool = { false }
    
    @Published public private(set) var lastPresentationTime: Date?
    @Published public private(set) var sessionAdCount: Int = 0
    @Published public private(set) var isFlowPaywallSuppressed: Bool = false
    
    private var triggerLastShown: [String: Date] = [:]
    
    public init() {}
    
    // MARK: - Flow & Session Management
    
    /// Resets per-session counters and flow suppression (called on scene background or new session).
    public func resetSession() {
        sessionAdCount = 0
        isFlowPaywallSuppressed = false
        GraceLogger.ads("Session reset: sessionAdCount=0, isFlowPaywallSuppressed=false", level: .info)
    }
    
    /// Flags whether the active completion flow offered or presented a paywall.
    public func setFlowPaywallSuppressed(_ suppressed: Bool) {
        self.isFlowPaywallSuppressed = suppressed
        if suppressed {
            GraceLogger.ads("Active flow suppressed ads due to active/offered paywall.", level: .info)
        }
    }
    
    // MARK: - Gatekeepers (Zero Wasted Requests)
    
    /// Gatekeeper check evaluated BEFORE sending any network request to load an ad.
    /// - Parameters:
    ///   - trigger: The trigger identifier (e.g. "after_quiz").
    ///   - isCacheValid: Whether an existing, unexpired ad is already in memory.
    /// - Returns: `true` if a network request should be sent; `false` to avoid wasting ad requests.
    public func canPreloadAd(for trigger: String, isCacheValid: Bool) -> Bool {
        if isProUser() {
            GraceLogger.ads("Preload skipped for '\(trigger)': User is Pro.", level: .info)
            return false
        }
        
        if isFlowPaywallSuppressed {
            GraceLogger.ads("Preload skipped for '\(trigger)': Flow has paywall active.", level: .info)
            return false
        }
        
        if isCacheValid {
            GraceLogger.ads("Preload skipped for '\(trigger)': Valid ad already cached and fresh.", level: .info)
            return false
        }
        
        if sessionAdCount >= config.maxPerSession {
            GraceLogger.ads("Preload skipped for '\(trigger)': Session cap reached (\(sessionAdCount)/\(config.maxPerSession)).", level: .info)
            return false
        }
        
        GraceLogger.ads("Preload approved for '\(trigger)'. Ready for network request.", level: .success)
        return true
    }
    
    /// Gatekeeper check evaluated BEFORE presenting an ad to the screen.
    /// - Parameter trigger: The trigger identifier (e.g. "after_quiz").
    /// - Returns: `true` if the ad can be safely presented; `false` if suppressed.
    public func canPresentAd(for trigger: String) -> Bool {
        if isProUser() {
            GraceLogger.ads("Presentation suppressed for '\(trigger)': User is Pro.", level: .info)
            return false
        }
        
        if isFlowPaywallSuppressed {
            GraceLogger.ads("Presentation suppressed for '\(trigger)': Flow presented/offered paywall.", level: .info)
            return false
        }
        
        // First-run exemption check
        if config.isFirstRunExempt {
            let defaults = UserDefaults.standard
            let isFirstRun = !defaults.bool(forKey: StorageKeys.hasCompletedFirstRunAdExemptionKey)
            if isFirstRun {
                defaults.set(true, forKey: StorageKeys.hasCompletedFirstRunAdExemptionKey)
                GraceLogger.ads("Presentation suppressed for '\(trigger)': First-run onboarding exemption applied.", level: .info)
                return false
            }
        }
        
        let now = Date()
        
        // Safety debounce check (anti-rapid-fire)
        if let last = lastPresentationTime {
            let elapsed = now.timeIntervalSince(last)
            if elapsed < config.safetyDebounce {
                GraceLogger.ads("Presentation suppressed for '\(trigger)': Safety debounce active (\(Int(elapsed))s < \(Int(config.safetyDebounce))s).", level: .warning)
                return false
            }
        }
        
        // Trigger cooldown check
        if let lastForTrigger = triggerLastShown[trigger] {
            let elapsed = now.timeIntervalSince(lastForTrigger)
            if elapsed < config.triggerCooldown {
                GraceLogger.ads("Presentation suppressed for '\(trigger)': Cooldown active (\(Int(elapsed))s < \(Int(config.triggerCooldown))s).", level: .warning)
                return false
            }
        }
        
        // Session cap check
        if sessionAdCount >= config.maxPerSession {
            GraceLogger.ads("Presentation suppressed for '\(trigger)': Session cap reached (\(sessionAdCount)/\(config.maxPerSession)).", level: .warning)
            return false
        }
        
        GraceLogger.ads("Presentation approved for '\(trigger)'.", level: .success)
        return true
    }
    
    /// Records a successful ad impression to update timestamps and session counts.
    public func recordAdPresented(for trigger: String) {
        let now = Date()
        lastPresentationTime = now
        triggerLastShown[trigger] = now
        sessionAdCount += 1
        GraceLogger.ads("Recorded presentation for '\(trigger)'. Session total: \(sessionAdCount)", level: .success)
    }
    
    // MARK: - Testing Helpers
    
    public func resetForTesting() {
        lastPresentationTime = nil
        triggerLastShown.removeAll()
        sessionAdCount = 0
        isFlowPaywallSuppressed = false
        isProUser = { false }
        UserDefaults.standard.removeObject(forKey: StorageKeys.hasCompletedFirstRunAdExemptionKey)
    }
}
