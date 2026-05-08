import Foundation

enum GraceAppsManager {
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

    static func getAllApps(excluding appIdToExclude: String? = nil) -> [GraceApp] {
        let apps = allGraceApps.filter { !$0.isExcluded }
        
        if let appIdToExclude {
            return apps.filter { $0.appId != appIdToExclude }
        }
        return apps
    }
    
    static func getAppStoreUrl(for appId: String) -> URL? {
        return getAllApps().first { $0.appId == appId }?.appStoreUrl
    }

    static func getSortedApps(excluding appIdToExclude: String? = nil) -> [GraceApp] {
        let allApps = allGraceApps.filter { !$0.isExcluded }
        let excludedApp = allGraceApps.first { $0.appId == appIdToExclude }
        let targetCategory = excludedApp?.category
        
        // Find the absolute newest app among available apps
        let availableApps = allApps.filter { $0.appId != appIdToExclude }
        let newestApp = availableApps.sorted(by: { 
            if $0.releaseDate != $1.releaseDate {
                return $0.releaseDate > $1.releaseDate
            }
            return $0.name < $1.name
        }).first
        
        return availableApps.sorted { app1, app2 in
            // 1. Priority: Same category as excluded app
            // This ensures audience relevance is prioritized over recency.
            if let targetCategory = targetCategory {
                if app1.category == targetCategory && app2.category != targetCategory {
                    return true
                }
                if app1.category != targetCategory && app2.category == targetCategory {
                    return false
                }
            }
            
            // 2. Priority: Absolute newest app (if not already handled by category)
            if let newestId = newestApp?.appId {
                if app1.appId == newestId { return true }
                if app2.appId == newestId { return false }
            }
            
            // 3. Default: Release date descending
            if app1.releaseDate != app2.releaseDate {
                return app1.releaseDate > app2.releaseDate
            }
            
            // 4. Stable alphabetical tie-breaker
            return app1.name < app2.name
        }
    }
}
