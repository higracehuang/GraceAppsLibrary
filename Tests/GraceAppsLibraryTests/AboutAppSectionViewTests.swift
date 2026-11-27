import XCTest
import SwiftUI
@testable import GraceAppsLibrary

final class AboutAppSectionViewTests: XCTestCase {
    
    func testNormalizedAppStoreId_withPrefix() {
        let view = AboutAppSectionView(appStoreId: "id123456789", releaseNotes: [])
        XCTAssertEqual(view.normalizedAppStoreId, "id123456789")
    }
    
    func testNormalizedAppStoreId_withoutPrefix() {
        let view = AboutAppSectionView(appStoreId: "123456789", releaseNotes: [])
        XCTAssertEqual(view.normalizedAppStoreId, "id123456789")
    }
    
    func testReviewURL() {
        let view = AboutAppSectionView(appStoreId: "123456789", releaseNotes: [])
        XCTAssertEqual(view.reviewURL?.absoluteString, "https://apps.apple.com/app/id123456789?action=write-review")
    }
    
    func testShareURL() {
        let view = AboutAppSectionView(appStoreId: "id123456789", releaseNotes: [])
        XCTAssertEqual(view.shareURL?.absoluteString, "https://apps.apple.com/app/id123456789")
    }
    
    func testInitialization() {
        let releaseNotes = [ReleaseNote(version: "1.0", notes: ["Test note"])]
        let view = AboutAppSectionView(appStoreId: "123456789", releaseNotes: releaseNotes)
        
        XCTAssertEqual(view.appStoreId, "123456789")
        XCTAssertEqual(view.releaseNotes.count, 1)
        XCTAssertEqual(view.releaseNotes.first?.version, "1.0")
    }
    
    func testInitializationWithoutReleaseNotes() {
        let view = AboutAppSectionView(appStoreId: "123456789")
        
        XCTAssertEqual(view.appStoreId, "123456789")
        XCTAssertTrue(view.releaseNotes.isEmpty)
    }

    func testBuildTypeAndDisplayVersionStringHideDebugDuringScreenshots() {
        let bundle = Bundle.main
        let expectedVersion = "\(bundle.releaseVersionNumber) (\(bundle.buildVersionNumber))"

        #if DEBUG
        XCTAssertEqual(bundle.resolvedBuildType(arguments: [], environment: [:]), "Debug")
        XCTAssertEqual(bundle.resolvedDisplayVersionString(arguments: [], environment: [:]), "Debug - \(expectedVersion)")

        XCTAssertEqual(bundle.resolvedBuildType(arguments: ["-SCREENSHOT_PRESET", "1"], environment: [:]), "")
        XCTAssertEqual(bundle.resolvedDisplayVersionString(arguments: ["-SCREENSHOT_PRESET", "1"], environment: [:]), expectedVersion)

        XCTAssertEqual(bundle.resolvedBuildType(arguments: [], environment: ["SCREENSHOT_PRESET": "1"]), "")
        XCTAssertEqual(bundle.resolvedDisplayVersionString(arguments: [], environment: ["SCREENSHOT_PRESET": "1"]), expectedVersion)

        XCTAssertEqual(bundle.resolvedBuildType(arguments: [], environment: ["IS_SCREENSHOT_ACTIVE": "1"]), "")
        XCTAssertEqual(bundle.resolvedDisplayVersionString(arguments: [], environment: ["IS_SCREENSHOT_ACTIVE": "1"]), expectedVersion)
        #else
        XCTAssertEqual(bundle.resolvedBuildType(arguments: [], environment: [:]), "")
        XCTAssertEqual(bundle.resolvedDisplayVersionString(arguments: [], environment: [:]), expectedVersion)
        #endif
    }
}
