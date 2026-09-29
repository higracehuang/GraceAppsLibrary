import XCTest
@testable import GraceAppsLibrary

final class ReleaseNotesTests: XCTestCase {
    var userDefaults: UserDefaults!
    var manager: ReleaseNotesManager!
    let suiteName = "ReleaseNotesTests"
    
    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
        manager = ReleaseNotesManager(userDefaults: userDefaults)
    }
    
    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }
    
    func testShouldShowReleaseNotes() {
        let releaseNotes = [
            ReleaseNote(version: "1.0.0", notes: ["Initial release"]),
            ReleaseNote(version: "2.0.0", notes: ["Big update"])
        ]
        
        // Test with version that has release notes
        XCTAssertTrue(manager.shouldShowReleaseNotes(currentVersion: "2.0.0", releaseNotes: releaseNotes))
        
        // Test with version that DOES NOT have release notes
        XCTAssertFalse(manager.shouldShowReleaseNotes(currentVersion: "1.5.0", releaseNotes: releaseNotes))
        
        // Test after marking as viewed
        manager.markAsViewed(version: "2.0.0")
        XCTAssertFalse(manager.shouldShowReleaseNotes(currentVersion: "2.0.0", releaseNotes: releaseNotes))
        
        // Test after update to new version
        XCTAssertTrue(manager.shouldShowReleaseNotes(currentVersion: "3.0.0", releaseNotes: [
            ReleaseNote(version: "3.0.0", notes: ["Newer update"])
        ]))
    }
    
    func testPersistence() {
        let version = "2.1.0"
        manager.markAsViewed(version: version)
        
        // Create a new manager with same user defaults to test persistence
        let newManager = ReleaseNotesManager(userDefaults: userDefaults)
        XCTAssertFalse(newManager.shouldShowReleaseNotes(currentVersion: version, releaseNotes: [
            ReleaseNote(version: version, notes: ["Test"])
        ]))
    }
    
    // MARK: - CTA & Link Support Tests
    
    func testReleaseNoteWebsiteURLCTA() {
        let webURL = URL(string: "https://ujiapps.com/guide")!
        let note = ReleaseNote(
            version: "1.2.0",
            notes: ["New brewing guide published."],
            ctaTitle: "Read Guide",
            ctaURL: webURL,
            ctaSystemImage: "safari"
        )
        
        XCTAssertTrue(note.hasCustomCTA)
        XCTAssertFalse(note.hasPaidFeature)
        XCTAssertFalse(note.effectiveRequiresUnpaidUser, "Website links should default to being shown to all users (both free and paid)")
        XCTAssertEqual(note.ctaURL, webURL)
        XCTAssertEqual(note.ctaSystemImage, "safari")
    }
    
    func testReleaseNoteCrossAppPromotionCTA() {
        let appStoreURL = URL(string: "https://apps.apple.com/app/id123456789")!
        let note = ReleaseNote(
            version: "1.19.0",
            items: [
                ReleaseNoteItem(text: "Sync with Dial In Pourovers!"),
                ReleaseNoteItem(text: "Beans automatically share across apps.")
            ],
            heroImageName: "ReleaseNotes/DIPOBanner",
            ctaTitle: "Get Dial In Pourovers",
            ctaURL: appStoreURL,
            ctaSystemImage: "arrow.down.app"
        )
        
        XCTAssertTrue(note.hasCustomCTA)
        XCTAssertFalse(note.hasPaidFeature)
        XCTAssertFalse(note.effectiveRequiresUnpaidUser, "Cross-app promotion links should default to being shown to all users")
        XCTAssertEqual(note.ctaURL, appStoreURL)
        XCTAssertEqual(note.ctaSystemImage, "arrow.down.app")
        XCTAssertEqual(note.heroImageName, "ReleaseNotes/DIPOBanner")
        XCTAssertEqual(note.effectiveHeroImageURL, appStoreURL)
    }
    
    func testReleaseNoteExplicitHeroImageURL() {
        let heroURL = URL(string: "https://example.com/hero")!
        let note = ReleaseNote(
            version: "1.20.0",
            notes: ["Test note"],
            heroImageName: "ReleaseNotes/Hero",
            heroImageURL: heroURL
        )
        
        XCTAssertEqual(note.heroImageURL, heroURL)
        XCTAssertEqual(note.effectiveHeroImageURL, heroURL)
    }
    
    func testReleaseNotePaywallActionDefaults() {
        // When note has a paid feature and custom action (without URL), it represents a paywall CTA
        var actionInvoked = false
        let paidNote = ReleaseNote(
            version: "2.0.0",
            items: [
                ReleaseNoteItem(text: "Basic improvement"),
                ReleaseNoteItem(text: "AI Feature", isPaidFeature: true)
            ],
            ctaTitle: "Upgrade to Pro",
            ctaAction: { actionInvoked = true }
        )
        
        XCTAssertTrue(paidNote.hasCustomCTA)
        XCTAssertTrue(paidNote.hasPaidFeature)
        XCTAssertTrue(paidNote.effectiveRequiresUnpaidUser, "Action on a note with paid features should default to requiring an unpaid user (hidden for paid users)")
        paidNote.ctaAction?()
        XCTAssertTrue(actionInvoked)
        
        // When note does NOT have a paid feature, custom action is treated as a general action shown to all users
        let freeNote = ReleaseNote(
            version: "2.0.1",
            items: [
                ReleaseNoteItem(text: "Free feature")
            ],
            ctaTitle: "Share Feedback",
            ctaAction: {}
        )
        XCTAssertTrue(freeNote.hasCustomCTA)
        XCTAssertFalse(freeNote.hasPaidFeature)
        XCTAssertFalse(freeNote.effectiveRequiresUnpaidUser, "Action on a note without paid features should be visible to all users")
    }
    
    func testReleaseNoteExplicitRequiresUnpaidOverride() {
        let webURL = URL(string: "https://example.com")!
        // Explicitly set ctaRequiresUnpaidUser to true even with a URL
        let noteRequiringUnpaid = ReleaseNote(
            version: "1.0.0",
            notes: ["Special promo for free tier only"],
            ctaTitle: "Claim Discount",
            ctaURL: webURL,
            ctaRequiresUnpaidUser: true
        )
        XCTAssertTrue(noteRequiringUnpaid.effectiveRequiresUnpaidUser)
        
        // Explicitly set ctaRequiresUnpaidUser to false even with a paid feature
        let noteAllowedForAll = ReleaseNote(
            version: "1.0.0",
            items: [
                ReleaseNoteItem(text: "Pro feature", isPaidFeature: true)
            ],
            ctaTitle: "Watch Tutorial",
            ctaURL: webURL,
            ctaRequiresUnpaidUser: false
        )
        XCTAssertFalse(noteAllowedForAll.effectiveRequiresUnpaidUser)
    }
    
    func testReleaseNoteBackwardCompatibility() {
        // Legacy initializer with notes array only
        let note1 = ReleaseNote(version: "1.0.0", notes: ["Note 1", "Note 2"])
        XCTAssertEqual(note1.items.count, 2)
        XCTAssertFalse(note1.hasCustomCTA)
        XCTAssertFalse(note1.hasPaidFeature)
        XCTAssertNil(note1.ctaURL)
        XCTAssertNil(note1.ctaAction)
        
        // Legacy initializer with items and hero image
        let note2 = ReleaseNote(
            version: "1.1.0",
            items: [ReleaseNoteItem(text: "Item 1", isPaidFeature: true)],
            heroImageName: "Hero"
        )
        XCTAssertEqual(note2.items.count, 1)
        XCTAssertTrue(note2.hasPaidFeature)
        XCTAssertFalse(note2.hasCustomCTA)
        XCTAssertEqual(note2.heroImageName, "Hero")
    }
    
    func testReleaseNoteIncompleteCTAConfiguration() {
        // Title only without URL or action -> not a valid custom CTA
        let titleOnlyNote = ReleaseNote(
            version: "1.0.0",
            notes: ["Note"],
            ctaTitle: "Click Me"
        )
        XCTAssertFalse(titleOnlyNote.hasCustomCTA)
        
        // URL only without title -> not a valid custom CTA
        let urlOnlyNote = ReleaseNote(
            version: "1.0.0",
            notes: ["Note"],
            ctaURL: URL(string: "https://example.com")
        )
        XCTAssertFalse(urlOnlyNote.hasCustomCTA)
        
        // Action only without title -> not a valid custom CTA
        let actionOnlyNote = ReleaseNote(
            version: "1.0.0",
            notes: ["Note"],
            ctaAction: {}
        )
        XCTAssertFalse(actionOnlyNote.hasCustomCTA)
    }
    
    func testFirstPaidNoteResolutionInMixedList() {
        let note1CrossPromo = ReleaseNote(
            version: "1.3.0",
            notes: ["Try our companion app Dial In Pourovers!"],
            ctaTitle: "Get DIPO",
            ctaURL: URL(string: "https://apps.apple.com"),
            ctaSystemImage: "arrow.down.app"
        )
        
        let note2PaidWithCustomCTA = ReleaseNote(
            version: "1.2.0",
            items: [
                ReleaseNoteItem(text: "AI Feature", isPaidFeature: true)
            ],
            ctaTitle: "Special Discount",
            ctaURL: URL(string: "https://example.com")
        )
        
        let note3FirstDefaultPaid = ReleaseNote(
            version: "1.1.0",
            items: [
                ReleaseNoteItem(text: "Cloud Sync", isPaidFeature: true)
            ]
        )
        
        let note4SecondDefaultPaid = ReleaseNote(
            version: "1.0.0",
            items: [
                ReleaseNoteItem(text: "Unlimited Exports", isPaidFeature: true)
            ]
        )
        
        let notes = [note1CrossPromo, note2PaidWithCustomCTA, note3FirstDefaultPaid, note4SecondDefaultPaid]
        
        // Verify individual note properties
        XCTAssertTrue(note1CrossPromo.hasCustomCTA)
        XCTAssertFalse(note1CrossPromo.hasPaidFeature)
        
        XCTAssertTrue(note2PaidWithCustomCTA.hasCustomCTA)
        XCTAssertTrue(note2PaidWithCustomCTA.hasPaidFeature)
        
        XCTAssertFalse(note3FirstDefaultPaid.hasCustomCTA)
        XCTAssertTrue(note3FirstDefaultPaid.hasPaidFeature)
        
        XCTAssertFalse(note4SecondDefaultPaid.hasCustomCTA)
        XCTAssertTrue(note4SecondDefaultPaid.hasPaidFeature)
        
        // Verify resolution of the default paywall note (first note with paid features and NO custom CTA)
        let resolvedFirstPaidNote = notes.first(where: { $0.hasPaidFeature && !$0.hasCustomCTA })
        XCTAssertEqual(resolvedFirstPaidNote?.id, note3FirstDefaultPaid.id, "Note 3 should be selected as the target for the paywall upgrade CTA")
    }
    
    func testReleaseNoteEqualityAndHashing() {
        let noteA = ReleaseNote(version: "1.0.0", notes: ["A"])
        let noteB = ReleaseNote(version: "1.0.0", notes: ["A"])
        
        // Different instances have different UUIDs
        XCTAssertNotEqual(noteA, noteB)
        
        var set: Set<ReleaseNote> = []
        set.insert(noteA)
        set.insert(noteB)
        XCTAssertEqual(set.count, 2)
        XCTAssertTrue(set.contains(noteA))
        XCTAssertTrue(set.contains(noteB))
    }
    
    func testReleaseNotesViewBodyRendering() {
        let notes = [
            ReleaseNote(
                version: "2.1.0",
                notes: ["Cross-promotion note"],
                ctaTitle: "Get DIPO",
                ctaURL: URL(string: "https://apps.apple.com"),
                ctaSystemImage: "arrow.down.app"
            ),
            ReleaseNote(
                version: "2.0.0",
                notes: ["Website link note"],
                ctaTitle: "Visit Site",
                ctaURL: URL(string: "https://example.com"),
                ctaSystemImage: "safari"
            ),
            ReleaseNote(
                version: "1.9.0",
                items: [
                    ReleaseNoteItem(text: "Paid Pro Feature", isPaidFeature: true)
                ]
            )
        ]
        
        // Free user view instantiation & body evaluation
        let freeUserView = ReleaseNotesView(
            releaseNotes: notes,
            isPaidUser: false,
            tierName: "Pro Tier",
            paywallAction: {},
            onDismiss: {}
        )
        XCTAssertNotNil(freeUserView.body)
        
        // Paid user view instantiation & body evaluation
        let paidUserView = ReleaseNotesView(
            releaseNotes: notes,
            isPaidUser: true,
            tierName: "Pro Tier",
            paywallAction: {},
            onDismiss: {}
        )
        XCTAssertNotNil(paidUserView.body)
    }
}
