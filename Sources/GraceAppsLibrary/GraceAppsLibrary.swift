// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

public struct GraceApp: Hashable {
    public let name: String
    public let iconName: String
    public let shortDescription: String
    public let appId: String
    public let appStoreUrl: URL
    public let releaseDate: Date
    
    public init(name: String, iconName: String, shortDescription: String, appId: String, releaseDate: Date) {
        self.name = name
        self.iconName = iconName
        self.shortDescription = shortDescription
        self.appId = appId
        self.appStoreUrl = URL(string: "https://apps.apple.com/app/\(appId)")!
        self.releaseDate = releaseDate
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
                releaseDate: Calendar.current.date(from: DateComponents(year: 2022, month: 7, day: 11))!
            ),
            GraceApp(
                name: "app.name.readingclock",
                iconName: "ReadingClockIcon",
                shortDescription: "app.description.readingclock",
                appId: "id6473550400",
                releaseDate: Calendar.current.date(from: DateComponents(year: 2023, month: 11, day: 30))!
            ),
            GraceApp(
                name: "app.name.stemcards",
                iconName: "StemCardsIcon",
                shortDescription: "app.description.stemcards",
                appId: "id6478243260",
                releaseDate: Calendar.current.date(from: DateComponents(year: 2024, month: 2, day: 27))!
            ),
            GraceApp(
                name: "app.name.stitchtally",
                iconName: "StitchTallyIcon",
                shortDescription: "app.description.stitchtally",
                appId: "id6738016114",
                releaseDate: Calendar.current.date(from: DateComponents(year: 2024, month: 11, day: 12))!
            ),
            GraceApp(
                name: "app.name.quizmeai",
                iconName: "QuizMeAIIcon",
                shortDescription: "app.description.quizmeai",
                appId: "id6720763773",
                releaseDate: Calendar.current.date(from: DateComponents(year: 2024, month: 10, day: 5))!
            ),
            GraceApp(
                name: "app.name.localspeaks",
                iconName: "LocalSpeaksIcon",
                shortDescription: "app.description.localspeaks",
                appId: "id6615060694",
                releaseDate: Calendar.current.date(from: DateComponents(year: 2024, month: 8, day: 7))!
            ),
            GraceApp(
                name: "app.name.itemizeai",
                iconName: "ItemizeAIIcon",
                shortDescription: "app.description.itemizeai",
                appId: "id6737280335",
                releaseDate: Calendar.current.date(from: DateComponents(year: 2024, month: 10, day: 27))!
            ),
            GraceApp(
                name: "app.name.chartybee",
                iconName: "ChartYBeeIcon",
                shortDescription: "app.description.chartybee",
                appId: "id6740661428",
                releaseDate: Calendar.current.date(from: DateComponents(year: 2025, month: 2, day: 10))!
            )
        ]
        
        if let appIdToExclude {
            return allApps.filter { $0.appId != appIdToExclude }
        }
        return allApps
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
