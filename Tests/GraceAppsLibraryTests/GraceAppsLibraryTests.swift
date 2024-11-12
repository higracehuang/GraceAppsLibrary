import XCTest
@testable import GraceAppsLibrary

final class GraceAppsLibraryTests: XCTestCase {
    func testGetAllApps() {
        let apps = GraceAppsLibrary.getAllApps()
        XCTAssertEqual(apps.count, 6, "Should return all 6 apps")
        
        // Test first app
        let tallyCoin = apps.first { $0.appId == "id1633932632" }
        XCTAssertNotNil(tallyCoin)
        XCTAssertEqual(tallyCoin?.iconName, "TallyCoinIcon")
        XCTAssertEqual(tallyCoin?.appStoreUrl.absoluteString, "https://apps.apple.com/app/id1633932632")
        
        // Test last app
        let itemizeAI = apps.first { $0.appId == "id6737280335" }
        XCTAssertNotNil(itemizeAI)
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
    
    func testLocalizations() throws {
        let apps = GraceAppsLibrary.getAllApps()
        let tallyCoin = try XCTUnwrap(apps.first { $0.appId == "id1633932632" })
        
        // Test English
        XCTAssertEqual(tallyCoin.localizedName, "TallyCoin")
        XCTAssertTrue(tallyCoin.localizedDescription.contains("tracking chores and rewards"))
        
        // Test Japanese
        let jaLocale = Locale(identifier: "ja")
        XCTAssertEqual(tallyCoin.localizedName(for: jaLocale), "TallyCoin タリーコイン")
        XCTAssertTrue(tallyCoin.localizedDescription(for: jaLocale).contains("家事や報酬を追跡"))
        
        // Test Chinese
        let zhLocale = Locale(identifier: "zh-Hans")
        XCTAssertEqual(tallyCoin.localizedName(for: zhLocale), "TallyCoin 劳动就打赏")
        XCTAssertTrue(tallyCoin.localizedDescription(for: zhLocale).contains("追踪家务和奖励"))
        
        // Test German
        let deLocale = Locale(identifier: "de")
        XCTAssertEqual(tallyCoin.localizedName(for: deLocale), "TallyCoin")
        XCTAssertTrue(tallyCoin.localizedDescription(for: deLocale).contains("Verfolgung von Aufgaben und Belohnungen"))
    }
}
