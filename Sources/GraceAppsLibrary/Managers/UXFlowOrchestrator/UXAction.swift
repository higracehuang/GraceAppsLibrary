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
    public let tags: Set<UXTag>
    
    let viewBuilder: (() -> AnyView)?
    let executionBlock: (@MainActor (_ completion: @escaping (UXActionOutcome) -> Void) -> Void)?
    
    /// Initializer for visual SwiftUI views (.sheet / .fullScreenCover)
    public init(
        id: String,
        priority: UXActionPriority = .milestone,
        kind: UXPresentationKind = .sheet,
        tags: Set<UXTag> = [],
        @ViewBuilder content: @escaping () -> some View
    ) {
        self.id = id
        self.priority = priority
        self.kind = kind
        self.tags = tags
        self.viewBuilder = { AnyView(content()) }
        self.executionBlock = nil
    }

    /// Backward-compatible initializer for visual SwiftUI views with Set<String> tags
    public init(
        id: String,
        priority: UXActionPriority = .milestone,
        kind: UXPresentationKind = .sheet,
        tags: Set<String>,
        @ViewBuilder content: @escaping () -> some View
    ) {
        self.id = id
        self.priority = priority
        self.kind = kind
        self.tags = Set(tags.map { UXTag($0) })
        self.viewBuilder = { AnyView(content()) }
        self.executionBlock = nil
    }
    
    /// Initializer for system prompts (.systemDialog) and custom vendor actions (.customAsync)
    public init(
        id: String,
        priority: UXActionPriority,
        kind: UXPresentationKind,
        tags: Set<UXTag> = [],
        execute: @escaping @MainActor (_ completion: @escaping (UXActionOutcome) -> Void) -> Void
    ) {
        self.id = id
        self.priority = priority
        self.kind = kind
        self.tags = tags
        self.viewBuilder = nil
        self.executionBlock = execute
    }

    /// Backward-compatible initializer for system prompts and custom vendor actions with Set<String> tags
    public init(
        id: String,
        priority: UXActionPriority,
        kind: UXPresentationKind,
        tags: Set<String>,
        execute: @escaping @MainActor (_ completion: @escaping (UXActionOutcome) -> Void) -> Void
    ) {
        self.id = id
        self.priority = priority
        self.kind = kind
        self.tags = Set(tags.map { UXTag($0) })
        self.viewBuilder = nil
        self.executionBlock = execute
    }
}

/// Identifiable wrapper for binding an active UXAction to SwiftUI presentation modifiers.
internal struct UXActionItem: Identifiable {
    var id: String { action.id }
    let action: UXAction
    
    internal init(action: UXAction) {
        self.action = action
    }
}

// MARK: - Standard Action Factories

extension UXAction {
    /// Creates a standard milestone or celebration results sheet action with priority `.milestone` (750).
    @MainActor
    public static func milestone(
        id: String = "milestone_sheet",
        tags: Set<UXTag> = [.celebration],
        @ViewBuilder content: @escaping () -> some View
    ) -> UXAction {
        UXAction(
            id: id,
            priority: .milestone,
            kind: .sheet,
            tags: tags,
            content: content
        )
    }

    /// Creates a standard commercial paywall modal action with priority `.paywall` (500).
    @MainActor
    public static func paywall(
        id: String = "paywall_sheet",
        kind: UXPresentationKind = .sheet,
        tags: Set<UXTag> = [.paywall],
        @ViewBuilder content: @escaping () -> some View
    ) -> UXAction {
        UXAction(
            id: id,
            priority: .paywall,
            kind: kind,
            tags: tags,
            content: content
        )
    }

    /// Creates a standard StoreKit native review prompt action with priority `.review` (250).
    ///
    /// - Parameters:
    ///   - id: Action identifier (default: `"rating_prompt"`).
    ///   - tags: Action tags (default: `[.review]`).
    ///   - onPrompt: Optional closure invoked to execute review prompt evaluation. If nil, invokes `ReviewPromptManager.shared.requestDirectNativeReview()`.
    @MainActor
    public static func ratingPrompt(
        id: String = "rating_prompt",
        tags: Set<UXTag> = [.review],
        onPrompt: (@MainActor () -> Bool)? = nil
    ) -> UXAction {
        UXAction(
            id: id,
            priority: .review,
            kind: .customAsync,
            tags: tags
        ) { completion in
            if let onPrompt = onPrompt {
                let approved = onPrompt()
                completion(approved ? .completed : .skipped)
            } else {
                ReviewPromptManager.shared.requestDirectNativeReview()
                completion(.completed)
            }
        }
    }

    /// Creates a standard interstitial ad action with priority `.ad` (100).
    ///
    /// - Parameters:
    ///   - id: Action identifier (default: `"interstitial_ad"`).
    ///   - tags: Action tags (default: `[.ad]`).
    ///   - present: Async closure to trigger the vendor ad presentation. Invokes `completion(true)` if presented, or `completion(false)` if skipped/throttled.
    @MainActor
    public static func ad(
        id: String = "interstitial_ad",
        tags: Set<UXTag> = [.ad],
        present: @escaping (@MainActor @escaping (_ wasPresented: Bool) -> Void) -> Void
    ) -> UXAction {
        UXAction(
            id: id,
            priority: .ad,
            kind: .customAsync,
            tags: tags
        ) { completion in
            present { wasPresented in
                completion(wasPresented ? .completed : .skipped)
            }
        }
    }
}
