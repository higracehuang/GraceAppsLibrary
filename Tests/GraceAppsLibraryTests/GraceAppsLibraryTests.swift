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
        let tallyCoinId = "id1633932632"
        let bundle = Bundle.module
        
        // Test English
        let enName = bundle.localizedString(forKey: "app.name.tallycoin", value: nil, table: nil)
        let enDesc = bundle.localizedString(forKey: "app.description.tallycoin", value: nil, table: nil)
        XCTAssertEqual(enName, "TallyCoin")
        XCTAssertTrue(enDesc.contains("tracking chores and rewards"))
        
        // Test Japanese
        let jaBundle = Bundle(path: try XCTUnwrap(bundle.path(forResource: "ja", ofType: "lproj")))
        let jaName = jaBundle?.localizedString(forKey: "app.name.tallycoin", value: nil, table: nil)
        let jaDesc = jaBundle?.localizedString(forKey: "app.description.tallycoin", value: nil, table: nil)
        XCTAssertEqual(jaName, "TallyCoin タリーコイン")
        XCTAssertTrue(jaDesc?.contains("家事や報酬を追跡") ?? false)
        
        // Test Chinese
        let zhBundle = Bundle(path: try XCTUnwrap(bundle.path(forResource: "zh-Hans", ofType: "lproj")))
        let zhName = zhBundle?.localizedString(forKey: "app.name.tallycoin", value: nil, table: nil)
        let zhDesc = zhBundle?.localizedString(forKey: "app.description.tallycoin", value: nil, table: nil)
        XCTAssertEqual(zhName, "TallyCoin 劳动就打赏")
        XCTAssertTrue(zhDesc?.contains("追踪家务和奖励") ?? false)
        
        // Test German
        let deBundle = Bundle(path: try XCTUnwrap(bundle.path(forResource: "de", ofType: "lproj")))
        let deName = deBundle?.localizedString(forKey: "app.name.tallycoin", value: nil, table: nil)
        let deDesc = deBundle?.localizedString(forKey: "app.description.tallycoin", value: nil, table: nil)
        XCTAssertEqual(deName, "TallyCoin")
        XCTAssertTrue(deDesc?.contains("Verfolgung von Aufgaben und Belohnungen") ?? false)
    }
}
