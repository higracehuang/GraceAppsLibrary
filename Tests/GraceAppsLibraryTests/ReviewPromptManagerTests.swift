import XCTest
@testable import GraceAppsLibrary

@MainActor
final class ReviewPromptManagerTests: XCTestCase {
    
    private let engagementKey = "GraceApps_Review_EngagementCounter"
    private let lastVersionKey = "GraceApps_Review_LastVersionPromptedForReview"
    private let appVersionKey = "GraceApps_Review_AppVersionForStorage"
    private let lastDateKey = "GraceApps_Review_LastEngagementDate"
    
    override func setUp() {
        super.setUp()
        ReviewPromptManager.debugResetEngagementCounter()
        UserDefaults.standard.removeObject(forKey: lastVersionKey)
        UserDefaults.standard.removeObject(forKey: appVersionKey)
        UserDefaults.standard.removeObject(forKey: lastDateKey)
    }
    
    override func tearDown() {
        ReviewPromptManager.debugResetEngagementCounter()
        UserDefaults.standard.removeObject(forKey: lastVersionKey)
        UserDefaults.standard.removeObject(forKey: appVersionKey)
        UserDefaults.standard.removeObject(forKey: lastDateKey)
        super.tearDown()
    }
    
    func testReviewAndShareURLs() {
        let appId = "id1633932632"
        let reviewURL = ReviewPromptManager.getReviewURL(appStoreId: appId)
        let shareURL = ReviewPromptManager.getShareURL(appStoreId: appId)
        
        XCTAssertNotNil(reviewURL)
        XCTAssertEqual(reviewURL?.absoluteString, "https://apps.apple.com/app/id1633932632?action=write-review")
        
        XCTAssertNotNil(shareURL)
        XCTAssertEqual(shareURL?.absoluteString, "https://apps.apple.com/app/id1633932632")
    }
    
    func testReviewURLWithRawDigits() {
        let rawId = "1633932632"
        let reviewURL = ReviewPromptManager.getReviewURL(appStoreId: rawId)
        XCTAssertEqual(reviewURL?.absoluteString, "https://apps.apple.com/app/id1633932632?action=write-review")
    }
    
    func testGetFeedbackMailURL() {
        let feedbackURL = ReviewPromptManager.getFeedbackMailURL()
        XCTAssertNotNil(feedbackURL)
        XCTAssertTrue(feedbackURL?.absoluteString.contains("mailto:\(Constants.feedbackEmail)") == true)
        XCTAssertTrue(feedbackURL?.absoluteString.contains("Feedback:") == true)
    }
    
    func testDebugResetEngagementCounter() {
        UserDefaults.standard.set(7, forKey: engagementKey)
        ReviewPromptManager.debugResetEngagementCounter()
        let count = UserDefaults.standard.integer(forKey: engagementKey)
        XCTAssertEqual(count, 0)
    }
    
    func testAppInitResetsCounterOnNewVersion() {
        UserDefaults.standard.set(10, forKey: engagementKey)
        UserDefaults.standard.set("0.9.0", forKey: appVersionKey)
        
        ReviewPromptManager.appInit()
        
        let storedVersion = UserDefaults.standard.string(forKey: appVersionKey)
        let count = UserDefaults.standard.integer(forKey: engagementKey)
        
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        XCTAssertEqual(storedVersion, currentVersion)
        XCTAssertEqual(count, 0)
    }
    
    func testHasPromptYet() {
        let manager = ReviewPromptManager.shared
        XCTAssertFalse(manager.hasPromptYet())
        
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        UserDefaults.standard.set(currentVersion, forKey: lastVersionKey)
        
        XCTAssertTrue(manager.hasPromptYet())
    }
    
    func testCheckpointCountThresholdLogic() {
        let manager = ReviewPromptManager(checkpointCount: 3)
        
        // 1st call -> count = 1 -> should not prompt
        XCTAssertFalse(manager.requestReviewIfNecessary())
        XCTAssertEqual(UserDefaults.standard.integer(forKey: engagementKey), 1)
        
        // 2nd call -> count = 2 -> should not prompt
        XCTAssertFalse(manager.requestReviewIfNecessary())
        XCTAssertEqual(UserDefaults.standard.integer(forKey: engagementKey), 2)
        
        // 3rd call -> count = 3 -> meets threshold, should prompt
        XCTAssertTrue(manager.requestReviewIfNecessary())
        XCTAssertEqual(UserDefaults.standard.integer(forKey: engagementKey), 3)
        
        // 4th call -> version marked as prompted, should not prompt again
        XCTAssertFalse(manager.requestReviewIfNecessary())
    }
    
    func testRequestReviewDailyThrottling() {
        let manager = ReviewPromptManager(checkpointCount: 1)
        
        // Yesterday date -> triggers prompt
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        UserDefaults.standard.set(yesterday, forKey: lastDateKey)
        
        XCTAssertTrue(manager.requestReviewIfNecessary())
        manager.requestReviewDaily()
        
        let lastDate = UserDefaults.standard.object(forKey: lastDateKey) as? Date
        XCTAssertNotNil(lastDate)
        XCTAssertTrue(Calendar.current.isDateInToday(lastDate!))
    }

    func testPositiveValueMomentsAndMilestones() {
        let manager = ReviewPromptManager.shared

        // Test milestone below threshold -> should not prompt
        let milestoneBelow = manager.recordMilestone(count: 1, threshold: 2, name: "test_milestone")
        XCTAssertFalse(milestoneBelow)

        // 1st moment achieving milestone -> should prompt since version not yet prompted
        let promptedFirst = manager.recordMilestone(count: 2, threshold: 2, name: "test_milestone")
        XCTAssertTrue(promptedFirst)

        let count = UserDefaults.standard.integer(forKey: "GraceApps_Review_EventCount_test_milestone")
        XCTAssertEqual(count, 1)

        // Subsequent positive moment on same version -> should NOT prompt again
        let promptedSecond = manager.recordPositiveValueMoment("custom_event")
        XCTAssertFalse(promptedSecond)

        let customCount = UserDefaults.standard.integer(forKey: "GraceApps_Review_EventCount_custom_event")
        XCTAssertEqual(customCount, 1)
    }
    
    func testAllLanguagesHaveReviewPromptKeys() {
        let locales = ["en", "de", "ja", "zh-Hans", "es"]
        let reviewKeys = [
            Constants.StringKeys.reviewPromptTitleFormat,
            Constants.StringKeys.reviewPromptMessage,
            Constants.StringKeys.reviewPromptPositive,
            Constants.StringKeys.reviewPromptNegative,
            Constants.StringKeys.reviewPromptRateThisApp
        ]
        
        for localeId in locales {
            guard let bundlePath = Bundle.module.path(forResource: localeId, ofType: "lproj"),
                  let langBundle = Bundle(path: bundlePath) else {
                XCTFail("Missing localization bundle for \(localeId)")
                continue
            }
            
            for key in reviewKeys {
                let localized = langBundle.localizedString(forKey: key, value: nil, table: nil)
                XCTAssertFalse(localized.isEmpty, "Empty localized string for key '\(key)' in \(localeId)")
                if localeId != "en" {
                    XCTAssertNotEqual(localized, key, "Missing localized string translation for key '\(key)' in \(localeId)")
                }
            }
        }
    }
}
