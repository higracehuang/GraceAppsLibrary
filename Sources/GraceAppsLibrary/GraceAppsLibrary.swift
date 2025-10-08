// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

public enum Category: String {
    case productivity = "Productivity"
    case education = "Education"
    case entertainment = "Entertainment"
    case health = "Health"
    case lifestyle = "Lifestyle"
    case social = "Social"
    case travel = "Travel"
    case utilities = "Utilities"
}

public struct GraceApp: Hashable {
    public let name: String
    public let iconName: String
    public let shortDescription: String
    public let appId: String
    public let appStoreUrl: URL
    public let releaseDate: Date
    public let category: Category
    public let isExcluded: Bool
    
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
    public static func getAllApps(excluding appIdToExclude: String? = nil) -> [GraceApp] {
        let allApps = [
            GraceApp(
                name: "app.name.tallycoin",
                iconName: "TallyCoinIcon",
                shortDescription: "app.description.tallycoin",
                appId: "id1633932632",
                releaseDate: Calendar.current.date(from: DateComponents(year: 2022, month: 7, day: 11))!,
                category: .productivity
            ),
            GraceApp(
                name: "app.name.readingclock",
                iconName: "ReadingClockIcon",
                shortDescription: "app.description.readingclock",
                appId: "id6473550400",
                releaseDate: Calendar.current.date(from: DateComponents(year: 2023, month: 11, day: 30))!,
                category: .productivity
            ),
            GraceApp(
                name: "app.name.stemcards",
                iconName: "StemCardsIcon",
                shortDescription: "app.description.stemcards",
                appId: "id6478243260",
                releaseDate: Calendar.current.date(from: DateComponents(year: 2024, month: 2, day: 27))!,
                category: .education
            ),
            GraceApp(
                name: "app.name.stitchtally",
                iconName: "StitchTallyIcon",
                shortDescription: "app.description.stitchtally",
                appId: "id6738016114",
                releaseDate: Calendar.current.date(from: DateComponents(year: 2024, month: 11, day: 12))!,
                category: .lifestyle
            ),
            GraceApp(
                name: "app.name.quizmeai",
                iconName: "QuizMeAIIcon",
                shortDescription: "app.description.quizmeai",
                appId: "id6720763773",
                releaseDate: Calendar.current.date(from: DateComponents(year: 2024, month: 10, day: 5))!,
                category: .education
            ),
            GraceApp(
                name: "app.name.localspeaks",
                iconName: "LocalSpeaksIcon",
                shortDescription: "app.description.localspeaks",
                appId: "id6615060694",
                releaseDate: Calendar.current.date(from: DateComponents(year: 2024, month: 8, day: 7))!,
                category: .education
            ),
            GraceApp(
                name: "app.name.itemizeai",
                iconName: "ItemizeAIIcon",
                shortDescription: "app.description.itemizeai",
                appId: "id6737280335",
                releaseDate: Calendar.current.date(from: DateComponents(year: 2024, month: 10, day: 27))!,
                category: .utilities,
                isExcluded: true
            ),
            GraceApp(
                name: "app.name.chartybee",
                iconName: "ChartYBeeIcon",
                shortDescription: "app.description.chartybee",
                appId: "id6740661428",
                releaseDate: Calendar.current.date(from: DateComponents(year: 2025, month: 2, day: 10))!,
                category: .utilities
            ),
            GraceApp(
                name: "app.name.snapprogress",
                iconName: "SnapProgressIcon",
                shortDescription: "app.description.snapprogress",
                appId: "id6745906297",
                releaseDate: Calendar.current.date(from: DateComponents(year: 2025, month: 5, day: 20))!,
                category: .utilities
            ),
            GraceApp(
                name: "app.name.dialinespresso",
                iconName: "DialInEspressoIcon",
                shortDescription: "app.description.dialinespresso",
                appId: "id6752831404",
                releaseDate: Calendar.current.date(from: DateComponents(year: 2025, month: 9, day: 22))!,
                category: .lifestyle
            ),
        ]

        let apps = allApps.filter { !$0.isExcluded }
        
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
