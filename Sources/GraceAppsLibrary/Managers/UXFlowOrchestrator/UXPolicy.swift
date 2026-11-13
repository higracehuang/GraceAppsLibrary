//
//  UXPolicy.swift
//  GraceAppsLibrary
//
//  Created by Grace Huang on 11/11/26.
//

import Foundation

/// Declarative rules governing presentation priority, mutual exclusions, cooldowns, and preconditions.
public struct UXPolicy {
    /// Mutual exclusions: If an action with tag A executes, suppress any action with tag B in the same flow.
    public var mutualExclusions: [UXTag: Set<UXTag>] = [:]
    
    /// Global minimum interval between consecutive modals/ads (anti-rapid-fire debounce).
    public var globalDebounce: TimeInterval = 15.0
    
    /// Minimum time in seconds required between executions of specific tags.
    public var tagCooldowns: [UXTag: TimeInterval] = [:]
    
    /// Maximum times an action ID can be executed within a single app session.
    public var sessionCaps: [String: Int] = [:]
    
    /// App-level preconditions (e.g., Pro subscription status, release version checks).
    public var preconditions: [String: () -> Bool] = [:]
    
    public init() {}
    
    /// Standard production policy:
    /// - Showing a review suppresses ads in the same flow.
    /// - Showing a paywall suppresses ads in the same flow.
    /// - 20s cooldown between consecutive ads.
    public static var standard: UXPolicy {
        var policy = UXPolicy()
        policy.mutuallyExclude(triggerTag: .review, suppressTag: .ad)
        policy.mutuallyExclude(triggerTag: .paywall, suppressTag: .ad)
        policy.setCooldown(tag: .ad, interval: 20)
        return policy
    }
    
    /// Adds a mutual exclusion rule. When `triggerTag` is executed, any action tagged with `suppressTag` is dropped.
    public mutating func mutuallyExclude(triggerTag: UXTag, suppressTag: UXTag) {
        var existing = mutualExclusions[triggerTag] ?? []
        existing.insert(suppressTag)
        mutualExclusions[triggerTag] = existing
    }
    
    /// Sets a cooldown interval for a specific tag.
    public mutating func setCooldown(tag: UXTag, interval: TimeInterval) {
        tagCooldowns[tag] = interval
    }
    
    /// Sets a maximum impression count per session for a specific action ID.
    public mutating func setSessionCap(actionId: String, maxCount: Int) {
        sessionCaps[actionId] = maxCount
    }
    
    /// Registers an app-level precondition closure that must return true for the action to be eligible.
    public mutating func setPrecondition(actionId: String, condition: @escaping () -> Bool) {
        preconditions[actionId] = condition
    }
}
