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
        self.name = name
        self.iconName = iconName
        self.shortDescription = shortDescription
        self.appId = appId
        self.appStoreUrl = URL(string: "https://apps.apple.com/app/\(appId)")!
    }
}

public enum GraceAppsLibrary {
    public static func getAllApps(excluding appIdToExclude: String? = nil) -> [GraceApp] {
        let allApps = [
            GraceApp(
                name: "TallyCoin",
                iconName: "TallyCoinIcon",
                shortDescription: "TallyCoin is the perfect app for tracking chores and rewards, designed with families in mind.",
                appId: "id1633932632"
            ),
            GraceApp(
                name: "ReadingClock",
                iconName: "ReadingClockIcon",
                shortDescription: "ReadingClock is a simple app to track your daily reading time and progress. By cultivating a consistent reading habit, you can improve your reading skills and expand your knowledge.",
                appId: "id6473550400"
            ),
            GraceApp(
                name: "Stem Cards",
                iconName: "StemCardsIcon",
                shortDescription: "Stem Cards is a fun and easy way to learn English word roots, prefixes, and suffixes.",
                appId: "id6478243260"
            ),
            GraceApp(
                name: "QuizMe.AI",
                iconName: "QuizMeAIIcon",
                shortDescription: "QuizMe.AI is an AI-powered quiz app that allows you to create quizzes on any topic from anything.",
                appId: "id6720763773"
            ),
            GraceApp(
                name: "LocalSpeaks",
                iconName: "LocalSpeaksIcon",
                shortDescription: "LocalSpeaks is a phrasebook app that helps you learn and practice authentic phrases in many different languages. Perfect for travelers and language learners.",
                appId: "id6615060694"
            ),
            GraceApp(
                name: "Itemize AI",
                iconName: "ItemizeAIIcon",
                shortDescription: "Itemize AI is an AI-powered app that analyzes any text, breaks it down into important bullet points, and summarizes it for you. Designed for visual readers.",
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
