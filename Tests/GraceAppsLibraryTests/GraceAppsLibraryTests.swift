import XCTest
@testable import GraceAppsLibrary

final class GraceAppsLibraryTests: XCTestCase {
    func testGetAllApps() {
        let apps = GraceAppsLibrary.getAllApps()
        XCTAssertEqual(apps.count, 6, "Should return all 6 apps")
        
        // Test first app
        let tallyCoin = apps.first { $0.appId == "id1633932632" }
        XCTAssertNotNil(tallyCoin)
        XCTAssertEqual(tallyCoin?.name, "TallyCoin")
        XCTAssertEqual(tallyCoin?.iconName, "TallyCoinIcon")
        XCTAssertEqual(tallyCoin?.appStoreUrl.absoluteString, "https://apps.apple.com/app/id1633932632")
        
        // Test last app
        let itemizeAI = apps.first { $0.appId == "id6737280335" }
        XCTAssertNotNil(itemizeAI)
        XCTAssertEqual(itemizeAI?.name, "Itemize AI")
        XCTAssertEqual(itemizeAI?.iconName, "ItemizeAIIcon")
        XCTAssertEqual(itemizeAI?.appStoreUrl.absoluteString, "https://apps.apple.com/app/id6737280335")
    }
    
    func testGetAllAppsWithExclusion() {
        let apps = GraceAppsLibrary.getAllApps(excluding: "id1633932632")
        XCTAssertEqual(apps.count, 5, "Should return 5 apps when excluding one")
        XCTAssertNil(apps.first { $0.appId == "id1633932632" }, "Excluded app should not be present")
    }
    
    func testGetAppStoreUrl() {
        // Test existing app
        let tallyUrl = GraceAppsLibrary.getAppStoreUrl(for: "id1633932632")
        XCTAssertNotNil(tallyUrl)
        XCTAssertEqual(tallyUrl?.absoluteString, "https://apps.apple.com/app/id1633932632")
        
        // Test non-existing app
        let nonExistingUrl = GraceAppsLibrary.getAppStoreUrl(for: "nonexisting")
        XCTAssertNil(nonExistingUrl)
    }
    
    func testLocalization() {
        let apps = GraceAppsLibrary.getAllApps()
        
        // Test TallyCoin localization
        let tallyCoin = apps.first { $0.appId == "id1633932632" }
        XCTAssertEqual(tallyCoin?.name, "TallyCoin")
        XCTAssertTrue(tallyCoin?.shortDescription.contains("tracking chores and rewards") ?? false)
        
        // Test ReadingClock localization
        let readingClock = apps.first { $0.appId == "id6473550400" }
        XCTAssertEqual(readingClock?.name, "ReadingClock")
        XCTAssertTrue(readingClock?.shortDescription.contains("track your daily reading time") ?? false)
    }
}
