import Foundation

public enum Category: String, Codable {
    case productivity = "Productivity"
    case education = "Education"
    case entertainment = "Entertainment"
    case health = "Health"
    case lifestyle = "Lifestyle"
    case social = "Social"
    case travel = "Travel"
    case utilities = "Utilities"
    
    public var symbolName: String {
        switch self {
        case .productivity: return "checklist"
        case .education: return "book.fill"
        case .entertainment: return "play.circle.fill"
        case .health: return "heart.fill"
        case .lifestyle: return "leaf.fill"
        case .social: return "person.2.fill"
        case .travel: return "airplane"
        case .utilities: return "wrench.and.screwdriver.fill"
        }
    }
}

public struct GraceApp: Hashable, Identifiable, Codable {
    public let name: String
    public let iconName: String
    public let shortDescription: String
    public let appId: String
    public let appStoreUrl: URL
    public let releaseDate: Date
    public let category: Category
    public let isExcluded: Bool
    
    public var id: String { appId }
    
    public init(name: String, iconName: String, shortDescription: String, appId: String, releaseDate: Date, category: Category, isExcluded: Bool = false) {
        self.name = name
        self.iconName = iconName
        self.shortDescription = shortDescription
        self.appId = appId
        self.appStoreUrl = URL(string: "https://apps.apple.com/app/\(appId)")!
        self.releaseDate = releaseDate
        self.category = category
        self.isExcluded = isExcluded
    }
    
    public var localizedName: String {
        Bundle.module.localizedString(forKey: name, value: nil, table: nil)
    }
    
    public func localizedName(for locale: Locale) -> String {
        let bundlePath = Bundle.module.path(forResource: locale.identifier, ofType: "lproj") ??
                        Bundle.module.path(forResource: locale.languageCode, ofType: "lproj")
        let languageBundle = bundlePath.flatMap { Bundle(path: $0) } ?? Bundle.module
        
        return languageBundle.localizedString(
            forKey: name,
            value: name,
            table: "Localizable"
        )
    }
    
    public var localizedDescription: String {
        Bundle.module.localizedString(forKey: shortDescription, value: nil, table: nil)
    }
    
    public func localizedDescription(for locale: Locale) -> String {
        let bundlePath = Bundle.module.path(forResource: locale.identifier, ofType: "lproj") ??
                        Bundle.module.path(forResource: locale.languageCode, ofType: "lproj")
        let languageBundle = bundlePath.flatMap { Bundle(path: $0) } ?? Bundle.module

        return languageBundle.localizedString(
            forKey: shortDescription,
            value: shortDescription,
            table: "Localizable"
        )
    }
}
