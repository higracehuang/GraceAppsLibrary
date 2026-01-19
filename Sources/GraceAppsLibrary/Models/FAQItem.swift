import SwiftUI

public struct FAQItem: Identifiable, Hashable {
    public let id = UUID()
    public let question: LocalizedStringKey
    public let answer: LocalizedStringKey
    
    public init(question: LocalizedStringKey, answer: LocalizedStringKey) {
        self.question = question
        self.answer = answer
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: FAQItem, rhs: FAQItem) -> Bool {
        lhs.id == rhs.id
    }
}

public struct FAQSection: Identifiable, Hashable {
    public let id = UUID()
    public let title: LocalizedStringKey
    public let items: [FAQItem]
    
    public init(title: LocalizedStringKey, items: [FAQItem]) {
        self.title = title
        self.items = items
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: FAQSection, rhs: FAQSection) -> Bool {
        lhs.id == rhs.id
    }
}
