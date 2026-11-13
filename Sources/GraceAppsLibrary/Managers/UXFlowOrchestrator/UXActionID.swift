//
//  UXActionID.swift
//  GraceAppsLibrary
//
//  Created by Grace Huang on 11/13/26.
//

import Foundation

/// Strongly-typed identifier for individual UX presentation actions, supporting preconditions, session caps, and deduplication.
public struct UXActionID: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible, Identifiable {
    public let rawValue: String

    public var id: String { rawValue }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public var description: String {
        rawValue
    }

    // MARK: - Standard Action Identifiers

    /// Full-screen interstitial advertisement action.
    public static let interstitialAd: UXActionID = "interstitial_ad"

    /// Native StoreKit rating prompt dialog action.
    public static let ratingPrompt: UXActionID   = "rating_prompt"

    /// Milestone / celebration results presentation action.
    public static let milestoneSheet: UXActionID = "milestone_sheet"

    /// Commercial paywall presentation action.
    public static let paywall: UXActionID        = "paywall"

    /// Celebration presentation action (alias of milestoneSheet).
    public static let celebration: UXActionID    = "milestone_sheet"
}

// MARK: - String Comparison Helpers

extension UXActionID {
    public static func == (lhs: UXActionID, rhs: String) -> Bool {
        lhs.rawValue == rhs
    }

    public static func == (lhs: String, rhs: UXActionID) -> Bool {
        lhs == rhs.rawValue
    }
}
