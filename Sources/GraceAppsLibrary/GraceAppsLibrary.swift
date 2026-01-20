// The Swift Programming Language
// https://docs.swift.org/swift-book

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

public enum GraceAppsLibrary {
    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private static let allGraceApps: [GraceApp] = [
        GraceApp(
            name: "app.name.tallycoin",
            iconName: "TallyCoinIcon",
            shortDescription: "app.description.tallycoin",
            appId: "id1633932632",
            releaseDate: date(2022, 7, 11),
            category: .productivity
        ),
        GraceApp(
            name: "app.name.readingclock",
            iconName: "ReadingClockIcon",
            shortDescription: "app.description.readingclock",
            appId: "id6473550400",
            releaseDate: date(2023, 11, 30),
            category: .productivity
        ),
        GraceApp(
            name: "app.name.stemcards",
            iconName: "StemCardsIcon",
            shortDescription: "app.description.stemcards",
            appId: "id6478243260",
            releaseDate: date(2024, 2, 27),
            category: .education
        ),
        GraceApp(
            name: "app.name.stitchtally",
            iconName: "StitchTallyIcon",
            shortDescription: "app.description.stitchtally",
            appId: "id6738016114",
            releaseDate: date(2024, 11, 12),
            category: .lifestyle
        ),
        GraceApp(
            name: "app.name.quizmeai",
            iconName: "QuizMeAIIcon",
            shortDescription: "app.description.quizmeai",
            appId: "id6720763773",
            releaseDate: date(2024, 10, 5),
            category: .education
        ),
        GraceApp(
            name: "app.name.localspeaks",
            iconName: "LocalSpeaksIcon",
            shortDescription: "app.description.localspeaks",
            appId: "id6615060694",
            releaseDate: date(2024, 8, 7),
            category: .education
        ),
        GraceApp(
            name: "app.name.itemizeai",
            iconName: "ItemizeAIIcon",
            shortDescription: "app.description.itemizeai",
            appId: "id6737280335",
            releaseDate: date(2024, 10, 27),
            category: .utilities,
            isExcluded: true
        ),
        GraceApp(
            name: "app.name.chartybee",
            iconName: "ChartYBeeIcon",
            shortDescription: "app.description.chartybee",
            appId: "id6740661428",
            releaseDate: date(2025, 2, 10),
            category: .utilities
        ),
        GraceApp(
            name: "app.name.snapprogress",
            iconName: "SnapProgressIcon",
            shortDescription: "app.description.snapprogress",
            appId: "id6745906297",
            releaseDate: date(2025, 5, 20),
            category: .utilities
        ),
        GraceApp(
            name: "app.name.dialinespresso",
            iconName: "DialInEspressoIcon",
            shortDescription: "app.description.dialinespresso",
            appId: "id6752831404",
            releaseDate: date(2025, 9, 22),
            category: .lifestyle
        ),
        GraceApp(
            name: "app.name.fastinglady",
            iconName: "FastingLadyIcon",
            shortDescription: "app.description.fastinglady",
            appId: "id6755406114",
            releaseDate: date(2025, 11, 21),
            category: .health
        ),
        GraceApp(
            name: "app.name.herweigh",
            iconName: "HerWeighIcon",
            shortDescription: "app.description.herweigh",
            appId: "id6757766090",
            releaseDate: date(2026, 1, 15),
            category: .health
        ),
    ]

    public static func getAllApps(excluding appIdToExclude: String? = nil) -> [GraceApp] {
        let apps = allGraceApps.filter { !$0.isExcluded }
        
        if let appIdToExclude {
            return apps.filter { $0.appId != appIdToExclude }
        }
        return apps
    }
    
    public static func getAppStoreUrl(for appId: String) -> URL? {
        return getAllApps().first { $0.appId == appId }?.appStoreUrl
    }

    public static func getSortedApps(excluding appIdToExclude: String? = nil) -> [GraceApp] {
        let apps = getAllApps(excluding: appIdToExclude)
                .sorted(by: { $0.releaseDate > $1.releaseDate })
        
        return apps
    }
}
