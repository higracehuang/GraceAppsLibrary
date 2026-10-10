import XCTest
import SwiftUI
@testable import GraceAppsLibrary

final class DebugViewsTests: XCTestCase {
    
    func testDebugStatusBadge() {
        let activeBadge = DebugStatusBadge("Active", isActive: true)
        XCTAssertTrue(activeBadge.isActive)
        
        let inactiveBadge = DebugStatusBadge("Pending", isActive: false)
        XCTAssertFalse(inactiveBadge.isActive)
    }
    
    func testDebugNavigationViewWithoutOnboarding() {
        var override = DebugEntitlementOverride.automatic
        let binding = Binding(get: { override }, set: { override = $0 })
        
        let navView = DebugNavigationView(
            title: "Dev Tools",
            systemImage: "wrench",
            includeReviews: true,
            entitlementOverride: binding,
            effectiveIsPro: true,
            tierName: "Pro Tier"
        ) {
            Text("Custom Dev Section")
        }
        
        XCTAssertEqual(navView.systemImage, "wrench")
        XCTAssertEqual(navView.includeReviews, true)
        XCTAssertEqual(navView.effectiveIsPro, true)
        XCTAssertNil(navView.onboardingView)
    }
    
    func testDebugNavigationViewWithOnboarding() {
        let navView = DebugNavigationView(
            onboardingView: {
                Text("Onboarding Sheet")
            },
            customContent: {
                Text("Custom Tools")
            }
        )
        
        XCTAssertNotNil(navView.onboardingView)
    }
    
    func testDebugMenuViewOfferings() async {
        let expectedOfferings = ["monthly_pro", "annual_pro", "lifetime"]
        
        let menuView = DebugMenuView(
            loadOfferings: {
                return expectedOfferings
            },
            onSelectOffering: { _ in }
        )
        
        XCTAssertNotNil(menuView.loadOfferings)
        let loaded = await menuView.loadOfferings?()
        XCTAssertEqual(loaded, expectedOfferings)
    }
    
    func testDebugSectionView() {
        let sectionView = DebugSectionView(
            sectionHeader: "Dev Tools",
            title: "Debug Options"
        ) {
            Text("Section Item")
        }
        
        XCTAssertEqual(sectionView.title, "Debug Options")
        XCTAssertTrue(sectionView.includeAppearance)
        XCTAssertTrue(sectionView.includeResetOverrides)
        XCTAssertNil(sectionView.onboardingView)
    }

    @MainActor
    func testDebugAppearanceManager() {
        XCTAssertEqual(DebugAppearanceManager.Mode.system.uiUserInterfaceStyle, .unspecified)
        XCTAssertEqual(DebugAppearanceManager.Mode.light.uiUserInterfaceStyle, .light)
        XCTAssertEqual(DebugAppearanceManager.Mode.dark.uiUserInterfaceStyle, .dark)

        DebugAppearanceManager.apply(mode: .light)
        DebugAppearanceManager.apply(mode: .dark)
        DebugAppearanceManager.apply(mode: .system)

        let section = DebugAppearanceSection()
        XCTAssertNotNil(section)
    }

    func testDebugEntitlementsSectionThreeWay() {
        var override = DebugEntitlementOverride.automatic
        let binding = Binding(get: { override }, set: { override = $0 })

        let section = DebugEntitlementsSection(
            override: binding,
            effectiveIsPro: true,
            tierName: "Pro Tier"
        )
        XCTAssertNotNil(section)

        override = .forcePro
        XCTAssertEqual(override, .forcePro)

        override = .forceFree
        XCTAssertEqual(override, .forceFree)
    }

    func testDebugResetSection() {
        var didResetCustom = false
        var override = DebugEntitlementOverride.forcePro
        let binding = Binding(get: { override }, set: { override = $0 })

        let resetSection = DebugResetSection(
            entitlementOverride: binding,
            onReset: {
                didResetCustom = true
            }
        )
        XCTAssertNotNil(resetSection)

        let menuView = DebugMenuView(
            includeResetOverrides: true,
            entitlementOverride: binding,
            onResetOverrides: {
                didResetCustom = true
            }
        )
        XCTAssertTrue(menuView.includeResetOverrides)
        XCTAssertNotNil(menuView.onResetOverrides)
        menuView.onResetOverrides?()
        XCTAssertTrue(didResetCustom)
    }
}
