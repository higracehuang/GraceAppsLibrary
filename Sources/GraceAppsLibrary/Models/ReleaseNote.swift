import SwiftUI

public struct ReleaseNoteItem: Identifiable, Hashable {
    public let id = UUID()
    public let text: LocalizedStringKey
    public let isPaidFeature: Bool
    
    public init(text: LocalizedStringKey, isPaidFeature: Bool = false) {
        self.text = text
        self.isPaidFeature = isPaidFeature
    }
    
    public static func == (lhs: ReleaseNoteItem, rhs: ReleaseNoteItem) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public struct ReleaseNote: Identifiable, Hashable {
    public let id = UUID()
    public let version: String
    public let items: [ReleaseNoteItem]
    public let heroImageName: String?
    
    public let ctaTitle: LocalizedStringKey?
    public let ctaURL: URL?
    public let ctaSystemImage: String?
    public let ctaAction: (() -> Void)?
    public let ctaRequiresUnpaidUser: Bool?
    
    /// Indicates whether this release note specifies a custom CTA (website URL, App Store link, or custom action).
    public var hasCustomCTA: Bool {
        ctaTitle != nil && (ctaURL != nil || ctaAction != nil)
    }
    
    /// Indicates whether any item in this release note is a paid/premium feature.
    public var hasPaidFeature: Bool {
        items.contains { $0.isPaidFeature }
    }
    
    /// Determines whether the CTA should only be displayed to unpaid users.
    /// If explicitly configured, respects `ctaRequiresUnpaidUser`.
    /// Otherwise, external links (`ctaURL != nil`) default to `false` (shown to all users),
    /// while actions on paid features default to `true` (hidden for paid users).
    public var effectiveRequiresUnpaidUser: Bool {
        if let explicit = ctaRequiresUnpaidUser {
            return explicit
        }
        if ctaURL != nil {
            return false
        }
        return hasPaidFeature
    }
    
    /// Full initializer with custom CTA (URL, custom action, SF Symbol icon, and unpaid user filtering).
    public init(
        version: String,
        items: [ReleaseNoteItem],
        heroImageName: String? = nil,
        ctaTitle: LocalizedStringKey? = nil,
        ctaURL: URL? = nil,
        ctaSystemImage: String? = nil,
        ctaRequiresUnpaidUser: Bool? = nil,
        ctaAction: (() -> Void)? = nil
    ) {
        self.version = version
        self.items = items
        self.heroImageName = heroImageName
        self.ctaTitle = ctaTitle
        self.ctaURL = ctaURL
        self.ctaSystemImage = ctaSystemImage
        self.ctaRequiresUnpaidUser = ctaRequiresUnpaidUser
        self.ctaAction = ctaAction
    }
    
    /// Backward-compatible initializer for existing code using items & ctaAction.
    public init(
        version: String,
        items: [ReleaseNoteItem],
        heroImageName: String? = nil,
        ctaTitle: LocalizedStringKey? = nil,
        ctaAction: (() -> Void)? = nil
    ) {
        self.init(
            version: version,
            items: items,
            heroImageName: heroImageName,
            ctaTitle: ctaTitle,
            ctaURL: nil,
            ctaSystemImage: nil,
            ctaRequiresUnpaidUser: nil,
            ctaAction: ctaAction
        )
    }

    /// Convenience initializer using an array of localized string keys with optional CTA configuration.
    public init(
        version: String,
        notes: [LocalizedStringKey],
        heroImageName: String? = nil,
        ctaTitle: LocalizedStringKey? = nil,
        ctaURL: URL? = nil,
        ctaSystemImage: String? = nil,
        ctaRequiresUnpaidUser: Bool? = nil,
        ctaAction: (() -> Void)? = nil
    ) {
        self.init(
            version: version,
            items: notes.map { ReleaseNoteItem(text: $0) },
            heroImageName: heroImageName,
            ctaTitle: ctaTitle,
            ctaURL: ctaURL,
            ctaSystemImage: ctaSystemImage,
            ctaRequiresUnpaidUser: ctaRequiresUnpaidUser,
            ctaAction: ctaAction
        )
    }

    public static func == (lhs: ReleaseNote, rhs: ReleaseNote) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
