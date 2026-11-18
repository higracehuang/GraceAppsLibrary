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
        ReviewPromptManager.debugResetReviewState()
        UserDefaults.standard.removeObject(forKey: lastVersionKey)
        UserDefaults.standard.removeObject(forKey: appVersionKey)
        UserDefaults.standard.removeObject(forKey: lastDateKey)
    }
    
    override func tearDown() {
        ReviewPromptManager.debugResetReviewState()
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
    
    func testDebugResetReviewState() {
        UserDefaults.standard.set(7, forKey: engagementKey)
        ReviewPromptManager.debugResetReviewState()
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
    
    func testReviewPromptSuppressedIfReleaseNotesShownThisSession() {
        let manager = ReviewPromptManager(checkpointCount: 1)
        
        // When release notes have been presented in this session
        ReleaseNotesManager.hasShownReleaseNotesThisSession = true
        
        // 1. requestReviewIfNecessary should be suppressed
        XCTAssertFalse(manager.requestReviewIfNecessary(), "Review prompt should be suppressed if release notes were already shown this session")
        
        // 2. recordPositiveValueMoment should also be suppressed
        let momentPrompted = manager.recordPositiveValueMoment("milestone_event")
        XCTAssertFalse(momentPrompted, "Positive value moment prompt should be suppressed if release notes were shown this session")
        
        // When session resets (e.g. new session)
        ReleaseNotesManager.hasShownReleaseNotesThisSession = false
        
        // Then review prompt can be evaluated normally
        XCTAssertTrue(manager.recordPositiveValueMoment("milestone_event_new_session"), "Positive value moment should prompt once new session has no release notes")
    }
    
    func testAllLanguagesHaveReviewPromptKeys() {
        let locales = ["en", "de", "ja", "zh-Hans", "es", "fr"]
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

    func testRequestDirectReviewIfEligible() {
        let manager = ReviewPromptManager.shared

        // 1. Below threshold -> false
        let belowThreshold = manager.requestDirectReviewIfEligible(currentCount: 1, threshold: 2, delay: 0)
        XCTAssertFalse(belowThreshold)

        // 2. Modal is presented -> false
        let modalPresented = manager.requestDirectReviewIfEligible(currentCount: 2, threshold: 2, isModalPresented: true, delay: 0)
        XCTAssertFalse(modalPresented)

        // 3. Release notes presented -> false
        ReleaseNotesManager.hasShownReleaseNotesThisSession = true
        let releaseNotesShown = manager.requestDirectReviewIfEligible(currentCount: 2, threshold: 2, delay: 0)
        XCTAssertFalse(releaseNotesShown)
        ReleaseNotesManager.hasShownReleaseNotesThisSession = false

        // 4. Eligible -> true
        let eligible = manager.requestDirectReviewIfEligible(currentCount: 2, threshold: 2, delay: 0)
        XCTAssertTrue(eligible)

        // 5. Once version is prompted -> false
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        UserDefaults.standard.set(currentVersion, forKey: lastVersionKey)
        let alreadyPrompted = manager.requestDirectReviewIfEligible(currentCount: 5, threshold: 2, delay: 0)
        XCTAssertFalse(alreadyPrompted)
    }

    func testHasPromptedForCurrentVersion() {
        let manager = ReviewPromptManager.shared
        XCTAssertFalse(manager.hasPromptedForCurrentVersion)

        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        UserDefaults.standard.set(currentVersion, forKey: lastVersionKey)
        XCTAssertTrue(manager.hasPromptedForCurrentVersion)
    }

    func testOpenAppStoreReviewPageReturnsFalseForInvalidId() {
        let opened = ReviewPromptManager.openAppStoreReviewPage(appStoreId: "")
        XCTAssertFalse(opened)
    }

    func testMajorMinorVersionParser() {
        XCTAssertEqual(ReviewPromptManager.majorMinorVersion(from: "2.1.0"), "2.1")
        XCTAssertEqual(ReviewPromptManager.majorMinorVersion(from: "2.1.3"), "2.1")
        XCTAssertEqual(ReviewPromptManager.majorMinorVersion(from: "2.0"), "2.0")
        XCTAssertEqual(ReviewPromptManager.majorMinorVersion(from: "3"), "3")
        XCTAssertEqual(ReviewPromptManager.majorMinorVersion(from: ""), "")
    }

    func testPatchVersionIgnoredForPromptEligibility() {
        let manager = ReviewPromptManager.shared
        manager.config = ReviewPromptConfig(ignorePatchVersions: true)

        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let parts = currentVersion.split(separator: ".")
        let patchVersion: String
        if parts.count >= 2 {
            patchVersion = "\(parts[0]).\(parts[1]).999"
        } else {
            patchVersion = "\(currentVersion).999"
        }

        UserDefaults.standard.set(patchVersion, forKey: lastVersionKey)
        XCTAssertTrue(manager.hasPromptedForCurrentVersion, "When ignorePatchVersions=true, a patch difference should still count as already prompted")

        manager.config.ignorePatchVersions = false
        XCTAssertFalse(manager.hasPromptedForCurrentVersion, "When ignorePatchVersions=false, exact version string must match")
    }

    func testCooldownSuppressionAndElapsed() {
        let manager = ReviewPromptManager.shared
        manager.config = ReviewPromptConfig(minDaysBetweenPrompts: 90)

        // 1. No prompt recorded yet -> cooldown passed
        UserDefaults.standard.removeObject(forKey: "GraceApps_Review_LastPromptDate")
        XCTAssertTrue(manager.hasPassedCooldown())

        // 2. Prompt recorded 10 days ago -> cooldown NOT passed
        let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        UserDefaults.standard.set(tenDaysAgo, forKey: "GraceApps_Review_LastPromptDate")
        XCTAssertFalse(manager.hasPassedCooldown())

        // 3. Prompt recorded 91 days ago -> cooldown passed
        let ninetyOneDaysAgo = Calendar.current.date(byAdding: .day, value: -91, to: Date())!
        UserDefaults.standard.set(ninetyOneDaysAgo, forKey: "GraceApps_Review_LastPromptDate")
        XCTAssertTrue(manager.hasPassedCooldown())
    }

    func testActiveDaysAndMilestonesGating() {
        let manager = ReviewPromptManager.shared
        manager.config = ReviewPromptConfig(minDaysBetweenPrompts: 0, minActiveDays: 3, minMilestoneEvents: 5)

        // 1. Initial state -> not met
        XCTAssertFalse(manager.hasMetValueThreshold())

        // 2. Record 2 days -> not yet met
        UserDefaults.standard.set(2, forKey: "GraceApps_Review_ActiveDaysCount")
        XCTAssertFalse(manager.hasMetValueThreshold())

        // 3. Record 3rd day -> met
        UserDefaults.standard.set(3, forKey: "GraceApps_Review_ActiveDaysCount")
        XCTAssertTrue(manager.hasMetValueThreshold())

        // 4. Reset active days and test milestones
        UserDefaults.standard.set(0, forKey: "GraceApps_Review_ActiveDaysCount")
        XCTAssertFalse(manager.hasMetValueThreshold())

        UserDefaults.standard.set(5, forKey: "GraceApps_Review_MilestoneCount")
        XCTAssertTrue(manager.hasMetValueThreshold())
    }

    func testReviewPromptStyleDirectVsIntermediateAlert() {
        let manager = ReviewPromptManager.shared
        manager.config = ReviewPromptConfig(
            style: .directNative,
            minDaysBetweenPrompts: 0,
            minActiveDays: 1,
            minMilestoneEvents: 1,
            ignorePatchVersions: true
        )
        UserDefaults.standard.set(1, forKey: "GraceApps_Review_ActiveDaysCount")

        // 1. Direct native style
        var negativeFeedbackInvoked = false
        let shownDirect = manager.requestReviewIfEligible(style: .directNative) {
            negativeFeedbackInvoked = true
        }
        XCTAssertTrue(shownDirect)
        XCTAssertFalse(negativeFeedbackInvoked)

        // Reset prompted state for next test
        UserDefaults.standard.removeObject(forKey: lastVersionKey)
        UserDefaults.standard.removeObject(forKey: "GraceApps_Review_LastPromptDate")

        // 2. Intermediate alert style
        let shownAlert = manager.requestReviewIfEligible(style: .intermediateAlert) {
            negativeFeedbackInvoked = true
        }
        XCTAssertTrue(shownAlert)
    }
}

