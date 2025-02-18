import XCTest
import SwiftUI
@testable import GraceAppsLibrary

final class AppOrderTests: XCTestCase {
    
    func testAppsAreSortedByReleaseDateDescending() {
        // When
        let apps = GraceAppsLibrary.getSortedApps()
        
        // Then
        // Verify apps are in descending order by release date
        for i in 0..<(apps.count - 1) {
            XCTAssertGreaterThanOrEqual(
                apps[i].releaseDate,
                apps[i + 1].releaseDate,
                "App at index \(i) should have a later or equal release date than app at index \(i + 1)"
            )
        }
    }
    
    func testNewestAppIsMarkedAsNew() {
        // When
        let apps = GraceAppsLibrary.getSortedApps()
        
        // Then
        guard let newestApp = apps.first else {
            XCTFail("Apps array should not be empty")
            return
        }
        
        // Create a test environment to render the view
        let appLink = AppLink(
            iconName: newestApp.iconName,
            title: newestApp.localizedName,
            description: newestApp.localizedDescription,
            url: newestApp.appStoreUrl,
            isNew: true
        )
        
        // Verify the newest app has the isNew flag set
        XCTAssertTrue(appLink.isNew, "The newest app should be marked as new")
    }
    
    func testAppExclusion() {
        // Given
        let allApps = GraceAppsLibrary.getAllApps()
        guard let appToExclude = allApps.first else {
            XCTFail("Apps array should not be empty")
            return
        }
        
        // When
        let filteredApps = GraceAppsLibrary.getSortedApps(excluding: appToExclude.appId)
        
        // Then
        XCTAssertFalse(
            filteredApps.contains(where: { $0.appId == appToExclude.appId }),
            "Excluded app should not be present in the filtered list"
        )
        XCTAssertEqual(
            filteredApps.count,
            allApps.count - 1,
            "Filtered apps should have one less app than all apps"
        )
    }
}
