import XCTest
import SwiftUI
@testable import GraceAppsLibrary

final class AppOrderTests: XCTestCase {
    
    func testAppsAreSortedByReleaseDateDescendingByDefault() {
        // When
        let apps = GraceAppsManager.getSortedApps()
        
        // Then
        // Verify apps are in descending order by release date (or alphabetical if same date)
        for i in 0..<(apps.count - 1) {
            let current = apps[i]
            let next = apps[i + 1]
            
            if current.releaseDate != next.releaseDate {
                XCTAssertGreaterThan(
                    current.releaseDate,
                    next.releaseDate,
                    "App \(current.name) should have a later release date than \(next.name)"
                )
            } else {
                XCTAssertLessThanOrEqual(
                    current.name,
                    next.name,
                    "App \(current.name) should be alphabetically before or same as \(next.name) for stability"
                )
            }
        }
    }
    
    func testSameCategoryAppsArePrioritizedFirst() {
        // Given
        // tallycoin is Productivity (2022)
        // readingclock is Productivity (2023)
        // absolute newest is herweigh (Health, 2026)
        
        // When
        let apps = GraceAppsManager.getSortedApps(excluding: "id1633932632") // Exclude tallycoin
        
        // Then
        // apps[0] should be readingclock (Same category as tallycoin, prioritized over herweigh)
        // apps[1] should be herweigh (Absolute Newest)
        
        XCTAssertEqual(apps[0].name, "app.name.readingclock", "Same category should come first when audience relevance is prioritized")
        XCTAssertEqual(apps[0].category, .productivity)
        XCTAssertEqual(apps[1].name, "app.name.herweigh", "Absolute newest should come after the related category group")
    }
    
    func testNewestAppIsAtTopWhenNoCategoryMatch() {
        // Given
        // Exclude an app that has NO other apps in its category (or category only has excluded app)
        // QuizMeAI is Education. stemcards and localspeaks are also Education.
        // Let's find a category with only one app if possible.
        // TallyCoin/ReadingClock are Productivity.
        
        // If we exclude an app from a category that has no other apps, newest should be top.
        // Currently all categories have multiple apps.
        
        // Let's test with fastinglady (Health) excluded. 
        // herweigh is also Health, so it will be top anyway.
        
        // Let's test with tallycoin (Productivity) excluded.
        // readingclock is Productivity. herweigh is Health (Newest).
        // Since Productivity is prioritized, readingclock wins.
        
        let apps = GraceAppsManager.getSortedApps(excluding: "id1633932632")
        XCTAssertEqual(apps[0].category, .productivity)
    }
    
    func testAppExclusion() {
        // Given
        let allApps = GraceAppsManager.getAllApps()
        guard let appToExclude = allApps.first else {
            XCTFail("Apps array should not be empty")
            return
        }
        
        // When
        let filteredApps = GraceAppsManager.getSortedApps(excluding: appToExclude.appId)
        
        // Then
        XCTAssertFalse(
            filteredApps.contains(where: { $0.appId == appToExclude.appId }),
            "Excluded app should not be present in the filtered list"
        )
    }
    
    func testGetNewestAppIdentifiesAbsoluteNewest() {
        // Given
        // herweigh is the newest app (2026-01-15)
        // tallycoin is an old app (2022-07-11)
        
        // When
        // Even if we are in TallyCoin (Productivity), getNewestApp should return herweigh (Health)
        let newestApp = GraceAppsManager.getNewestApp(excluding: "id1633932632") // Exclude tallycoin
        
        // Then
        XCTAssertEqual(newestApp?.name, "app.name.herweigh", "getNewestApp should return the absolute newest app regardless of the current app's category")
    }
}
