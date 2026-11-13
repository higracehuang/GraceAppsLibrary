//
//  UXTag.swift
//  GraceAppsLibrary
//
//  Created by Grace Huang on 11/12/26.
//

import Foundation

/// Strongly-typed identifier for categorizing presentation actions and configuring mutual exclusions, cooldowns, and debouncing.
public struct UXTag: Hashable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String
    
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
    
    public init(stringLiteral value: String) {
        self.rawValue = value
    }
    
    public var description: String {
        rawValue
    }
    
    // MARK: - Standard Tags
    
    /// Milestone or achievement celebration results modal.
    public static let celebration: UXTag = "celebration"
    
    /// Commercial conversion, subscription, or paywall modal.
    public static let paywall: UXTag     = "paywall"
    
    /// App Store rating and review request prompt.
    public static let review: UXTag      = "review"
    
    /// Full-screen interstitial or rewarded monetization advertisement.
    public static let ad: UXTag          = "ad"
}
