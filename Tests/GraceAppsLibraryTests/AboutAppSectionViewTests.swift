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
}
