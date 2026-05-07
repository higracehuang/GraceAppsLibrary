import SwiftUI

public struct SourceLink: Identifiable, Hashable {
    public let id = UUID()
    public let title: LocalizedStringKey
    public let subtitle: LocalizedStringKey?
    public let url: URL
    
    public init(title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil, url: URL) {
        self.title = title
        self.subtitle = subtitle
        self.url = url
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: SourceLink, rhs: SourceLink) -> Bool {
        lhs.id == rhs.id
    }
}

public struct SourceSection: Identifiable, Hashable {
    public let id = UUID()
    public let title: LocalizedStringKey
    public let footer: LocalizedStringKey?
    public let links: [SourceLink]
    
    public init(title: LocalizedStringKey, footer: LocalizedStringKey? = nil, links: [SourceLink]) {
        self.title = title
        self.footer = footer
        self.links = links
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: SourceSection, rhs: SourceSection) -> Bool {
        lhs.id == rhs.id
    }
}
