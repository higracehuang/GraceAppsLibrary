// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

public struct GraceApp: Hashable {
    public let name: String
    public let iconName: String
    public let shortDescription: String
    public let appId: String
    public let appStoreUrl: URL
    
    public init(name: String, iconName: String, shortDescription: String, appId: String) {
        self.name = name
        self.iconName = iconName
        self.shortDescription = shortDescription
        self.appId = appId
        self.appStoreUrl = URL(string: "https://apps.apple.com/app/\(appId)")!
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
                appId: "id1633932632"
            ),
            GraceApp(
                name: "app.name.readingclock",
                iconName: "ReadingClockIcon",
                shortDescription: "app.description.readingclock",
                appId: "id6473550400"
            ),
            GraceApp(
                name: "app.name.stemcards",
                iconName: "StemCardsIcon",
                shortDescription: "app.description.stemcards",
                appId: "id6478243260"
            ),
            GraceApp(
                name: "app.name.stitchtally",
                iconName: "StitchTallyIcon",
                shortDescription: "app.description.stitchtally",
                appId: "id6738016114"
            ),
            GraceApp(
                name: "app.name.quizmeai",
                iconName: "QuizMeAIIcon",
                shortDescription: "app.description.quizmeai",
                appId: "id6720763773"
            ),
            GraceApp(
                name: "app.name.localspeaks",
                iconName: "LocalSpeaksIcon",
                shortDescription: "app.description.localspeaks",
                appId: "id6615060694"
            ),
            GraceApp(
                name: "app.name.itemizeai",
                iconName: "ItemizeAIIcon",
                shortDescription: "app.description.itemizeai",
                appId: "id6737280335"
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
}
