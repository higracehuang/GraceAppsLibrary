//
//  UXAction.swift
//  GraceAppsLibrary
//
//  Created by Grace Huang on 11/11/26.
//

import SwiftUI

/// Defines the visual or execution format of an action in the presentation pipeline.
public enum UXPresentationKind: Sendable {
    /// Native SwiftUI modal sheet
    case sheet
    /// Native SwiftUI full-screen modal cover
    case fullScreenCover
    /// System dialogs that require an unoccluded foreground window (e.g., StoreKit Review, Notification Permission)
    case systemDialog
    /// Custom asynchronous workflows (e.g., AdMob Interstitials, custom view controller presentations)
    case customAsync
}

/// Priority tier determining presentation order when multiple actions trigger simultaneously.
public struct UXActionPriority: Comparable, Sendable, Hashable {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    /// User explicitly requested an action (e.g. tapped "Go Pro" or "Settings Upgrade")
    public static let critical  = UXActionPriority(rawValue: 1000)
    /// Peak milestone / celebration / completion results sheet
    public static let milestone = UXActionPriority(rawValue: 750)
    /// Commercial conversion / upsell paywall
    public static let paywall   = UXActionPriority(rawValue: 500)
    /// StoreKit App Store rating / review prompt
    public static let review    = UXActionPriority(rawValue: 250)
    /// Monetization interstitial ad
    public static let ad        = UXActionPriority(rawValue: 100)

    public static func < (lhs: UXActionPriority, rhs: UXActionPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// The result returned by an action upon completion.
public enum UXActionOutcome: Sendable {
    case completed
    case dismissed
    case cancelled
    case skipped
}

/// An action-agnostic presentation unit managed by UXFlowOrchestrator.
public struct UXAction: Identifiable {
    public let id: String
    public let priority: UXActionPriority
    public let kind: UXPresentationKind
    public let tags: Set<String>
    
    let viewBuilder: (() -> AnyView)?
    let executionBlock: ((_ completion: @escaping (UXActionOutcome) -> Void) -> Void)?
    
    /// Initializer for visual SwiftUI views (.sheet / .fullScreenCover)
    public init(
        id: String,
        priority: UXActionPriority = .milestone,
        kind: UXPresentationKind = .sheet,
        tags: Set<String> = [],
        @ViewBuilder content: @escaping () -> some View
    ) {
        self.id = id
        self.priority = priority
        self.kind = kind
        self.tags = tags
        self.viewBuilder = { AnyView(content()) }
        self.executionBlock = nil
    }
    
    /// Initializer for system prompts (.systemDialog) and custom vendor actions (.customAsync)
    public init(
        id: String,
        priority: UXActionPriority,
        kind: UXPresentationKind,
        tags: Set<String> = [],
        execute: @escaping (_ completion: @escaping (UXActionOutcome) -> Void) -> Void
    ) {
        self.id = id
        self.priority = priority
        self.kind = kind
        self.tags = tags
        self.viewBuilder = nil
        self.executionBlock = execute
    }
}

/// Identifiable wrapper for binding an active UXAction to SwiftUI presentation modifiers.
public struct UXActionItem: Identifiable {
    public var id: String { action.id }
    public let action: UXAction
    
    public init(action: UXAction) {
        self.action = action
    }
}
