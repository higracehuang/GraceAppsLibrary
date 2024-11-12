// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

public struct GraceApp {
    public let name: String
    public let iconName: String
    public let shortDescription: String
    public let appId: String
    public let appStoreUrl: URL
    
    public init(name: String, iconName: String, shortDescription: String, appId: String) {
        self.name = NSLocalizedString(name, bundle: .module, comment: "App name")
        self.iconName = iconName
        self.shortDescription = NSLocalizedString(shortDescription, bundle: .module, comment: "App description")
        self.appId = appId
        self.appStoreUrl = URL(string: "https://apps.apple.com/app/\(appId)")!
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
