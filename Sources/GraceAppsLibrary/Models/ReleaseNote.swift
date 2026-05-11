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
    public let ctaAction: (() -> Void)?
    
    public init(version: String, items: [ReleaseNoteItem], heroImageName: String? = nil, ctaTitle: LocalizedStringKey? = nil, ctaAction: (() -> Void)? = nil) {
        self.version = version
        self.items = items
        self.heroImageName = heroImageName
        self.ctaTitle = ctaTitle
        self.ctaAction = ctaAction
    }
    
    public init(version: String, notes: [LocalizedStringKey], heroImageName: String? = nil) {
        self.version = version
        self.items = notes.map { ReleaseNoteItem(text: $0) }
        self.heroImageName = heroImageName
        self.ctaTitle = nil
        self.ctaAction = nil
    }

    public static func == (lhs: ReleaseNote, rhs: ReleaseNote) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
