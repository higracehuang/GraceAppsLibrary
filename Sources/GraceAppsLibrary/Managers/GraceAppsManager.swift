import Foundation

public enum GraceAppsManager {
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
