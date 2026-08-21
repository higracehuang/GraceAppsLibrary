import XCTest
@testable import GraceAppsLibrary

final class GraceAppsLibraryTests: XCTestCase {
    func testGetAllApps() {
        let apps = GraceAppsManager.getAllApps()
        XCTAssertEqual(apps.count, 11, "Should return all 11 apps")
        
        // Test first app
        let tallyCoin = apps.first { $0.appId == "id1633932632" }
        XCTAssertNotNil(tallyCoin)
        XCTAssertEqual(tallyCoin?.iconName, "TallyCoinIcon")
        XCTAssertEqual(tallyCoin?.appStoreUrl.absoluteString, "https://apps.apple.com/app/id1633932632")
        
        // Test last app
        let chartyBee = apps.first { $0.appId == "id6740661428" }
        XCTAssertNotNil(chartyBee)
        XCTAssertEqual(chartyBee?.iconName, "ChartYBeeIcon")
        XCTAssertEqual(chartyBee?.appStoreUrl.absoluteString, "https://apps.apple.com/app/id6740661428")
    }
    
    func testGetAllAppsWithExclusion() {
        let apps = GraceAppsManager.getAllApps(excluding: "id1633932632")
        XCTAssertEqual(apps.count, 10, "Should return 10 apps when excluding one")
        XCTAssertNil(apps.first { $0.appId == "id1633932632" }, "Excluded app should not be present")
    }
    
    func testGetAppStoreUrl() {
        // Test existing app
        let tallyUrl = GraceAppsManager.getAppStoreUrl(for: "id1633932632")
        XCTAssertNotNil(tallyUrl)
        XCTAssertEqual(tallyUrl?.absoluteString, "https://apps.apple.com/app/id1633932632")
        
        // Test non-existing app
        let nonExistingUrl = GraceAppsManager.getAppStoreUrl(for: "nonexisting")
        XCTAssertNil(nonExistingUrl)
    }
    
    func testLocalizations() throws {
        let apps = GraceAppsManager.getAllApps()
        let tallyCoin = try XCTUnwrap(apps.first { $0.appId == "id1633932632" })
        let chartyBee = try XCTUnwrap(apps.first { $0.appId == "id6740661428" })
        
        // Test English
        XCTAssertEqual(tallyCoin.localizedName, "TallyCoin")
        XCTAssertTrue(tallyCoin.localizedDescription.contains("tracking chores and rewards"))
        XCTAssertEqual(chartyBee.localizedName, "ChartyBee")
        XCTAssertTrue(chartyBee.localizedDescription.contains("track many little things in life"))
        
        // Test StitchTally name
        let stitchTally = try XCTUnwrap(apps.first { $0.appId == "id6738016114" })
        XCTAssertEqual(stitchTally.localizedName, "StitchTally")
        
        // Test Japanese
        let jaLocale = Locale(identifier: "ja")
        XCTAssertEqual(tallyCoin.localizedName(for: jaLocale), "TallyCoin タリーコイン")
        XCTAssertTrue(tallyCoin.localizedDescription(for: jaLocale).contains("家事や報酬を追跡"))
        XCTAssertEqual(chartyBee.localizedName(for: jaLocale), "ChartyBee チャーティービー")
        XCTAssertTrue(chartyBee.localizedDescription(for: jaLocale).contains("小さなトラッキングアプリ"))
        
        // Test Chinese
        let zhLocale = Locale(identifier: "zh-Hans")
        XCTAssertEqual(tallyCoin.localizedName(for: zhLocale), "TallyCoin 劳动就打赏")
        XCTAssertTrue(tallyCoin.localizedDescription(for: zhLocale).contains("追踪家务和奖励"))
        XCTAssertEqual(chartyBee.localizedName(for: zhLocale), "ChartyBee 图表小蜜蜂")
        XCTAssertTrue(chartyBee.localizedDescription(for: zhLocale).contains("点点滴滴"))
        
        // Test German
        let deLocale = Locale(identifier: "de")
        XCTAssertEqual(tallyCoin.localizedName(for: deLocale), "TallyCoin")
        XCTAssertTrue(tallyCoin.localizedDescription(for: deLocale).contains("Verfolgung von Aufgaben und Belohnungen"))
        XCTAssertEqual(chartyBee.localizedName(for: deLocale), "ChartyBee")
        XCTAssertTrue(chartyBee.localizedDescription(for: deLocale).contains("Kleine Tracking-App"))
        
        // Test Spanish
        let esLocale = Locale(identifier: "es")
        XCTAssertEqual(tallyCoin.localizedName(for: esLocale), "TallyCoin")
        XCTAssertTrue(tallyCoin.localizedDescription(for: esLocale).contains("seguimiento de tareas del hogar y recompensas"))
        XCTAssertEqual(chartyBee.localizedName(for: esLocale), "ChartyBee")
        XCTAssertTrue(chartyBee.localizedDescription(for: esLocale).contains("Pequeña app de seguimiento"))
        
        // Test Dial In Espresso
        let dialInEspresso = try XCTUnwrap(apps.first { $0.appId == "id6752831404" })
        XCTAssertEqual(dialInEspresso.localizedName(for: deLocale), "Dial In Espresso")
        XCTAssertTrue(dialInEspresso.localizedDescription(for: deLocale).contains("Einfache App"))
        XCTAssertEqual(dialInEspresso.localizedName(for: esLocale), "Dial In Espresso")
        XCTAssertTrue(dialInEspresso.localizedDescription(for: esLocale).contains("granos y extracciones"))
    }
    
    func testAllAppsHaveAllLocalizations() {
        let apps = GraceAppsManager.getAllApps()
        let locales = ["en", "de", "ja", "zh-Hans", "es"]
        
        let sharedKeys = [
            Constants.StringKeys.feedbackMessage,
            Constants.StringKeys.feedbackAppreciation,
            Constants.StringKeys.feedbackSignature,
            Constants.StringKeys.feedbackTitle,
            Constants.StringKeys.otherAppsByGrace,
            Constants.StringKeys.otherAppsBuiltByGrace,
            Constants.StringKeys.appsIntroduction,
            Constants.StringKeys.labelNew,
            Constants.StringKeys.labelGet
        ]
        
        for localeId in locales {
            let bundlePath = Bundle.module.path(forResource: localeId, ofType: "lproj")
            let bundle = bundlePath.flatMap { Bundle(path: $0) }
            XCTAssertNotNil(bundle, "Bundle for locale \(localeId) should exist")
            
            guard let langBundle = bundle else { continue }
            
            // Check apps
            for app in apps {
                let name = langBundle.localizedString(forKey: app.name, value: nil, table: nil)
                let description = langBundle.localizedString(forKey: app.shortDescription, value: nil, table: nil)
                
                XCTAssertNotEqual(name, app.name, "Missing name translation for \(app.appId) in \(localeId)")
                XCTAssertNotEqual(description, app.shortDescription, "Missing description translation for \(app.appId) in \(localeId)")
            }
            
            // Check shared keys
            for key in sharedKeys {
                let localized = langBundle.localizedString(forKey: key, value: nil, table: nil)
                XCTAssertNotEqual(localized, key, "Missing shared translation for key '\(key)' in \(localeId)")
            }
        }
    }
}
