import Foundation

enum Category: String, Codable {
    case productivity = "Productivity"
    case education = "Education"
    case entertainment = "Entertainment"
    case health = "Health"
    case lifestyle = "Lifestyle"
    case social = "Social"
    case travel = "Travel"
    case utilities = "Utilities"
    
    var symbolName: String {
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

struct GraceApp: Hashable, Identifiable, Codable {
    let name: String
    let iconName: String
    let shortDescription: String
    let appId: String
    let appStoreUrl: URL
    let releaseDate: Date
    let category: Category
    let isExcluded: Bool
    
    var id: String { appId }
    
    init(name: String, iconName: String, shortDescription: String, appId: String, releaseDate: Date, category: Category, isExcluded: Bool = false) {
        self.name = name
        self.iconName = iconName
        self.shortDescription = shortDescription
        self.appId = appId
        self.appStoreUrl = URL(string: "https://apps.apple.com/app/\(appId)")!
        self.releaseDate = releaseDate
        self.category = category
        self.isExcluded = isExcluded
    }
    
    var localizedName: String {
        Bundle.module.localizedString(forKey: name, value: nil, table: nil)
    }
    
    func localizedName(for locale: Locale) -> String {
        let bundlePath = Bundle.module.path(forResource: locale.identifier, ofType: "lproj") ??
                        Bundle.module.path(forResource: locale.languageCode, ofType: "lproj")
        let languageBundle = bundlePath.flatMap { Bundle(path: $0) } ?? Bundle.module
        
        return languageBundle.localizedString(
            forKey: name,
            value: name,
            table: "Localizable"
        )
    }
    
    var localizedDescription: String {
        Bundle.module.localizedString(forKey: shortDescription, value: nil, table: nil)
    }
    
    func localizedDescription(for locale: Locale) -> String {
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
