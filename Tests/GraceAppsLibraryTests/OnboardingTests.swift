import XCTest
import SwiftUI
@testable import GraceAppsLibrary

final class OnboardingTests: XCTestCase {
    
    private var testUserDefaults: UserDefaults!
    private let testSuiteName = "OnboardingTestsSuite"
    
    override func setUp() {
        super.setUp()
        testUserDefaults = UserDefaults(suiteName: testSuiteName)
        testUserDefaults?.removePersistentDomain(forName: testSuiteName)
    }
    
    override func tearDown() {
        testUserDefaults?.removePersistentDomain(forName: testSuiteName)
        testUserDefaults = nil
        super.tearDown()
    }
    
    // MARK: - OnboardingCoordinator Tests
    
    func testCoordinatorInitialState() {
        let coordinator = OnboardingCoordinator(initialStep: 0, totalSteps: 4)
        
        XCTAssertEqual(coordinator.currentStep, 0)
        XCTAssertEqual(coordinator.totalSteps, 4)
        XCTAssertTrue(coordinator.isFirstStep)
        XCTAssertFalse(coordinator.isLastStep)
        XCTAssertEqual(coordinator.progress, 0.25, accuracy: 0.001)
    }
    
    func testCoordinatorClampingOnInitialization() {
        let overstepped = OnboardingCoordinator(initialStep: 10, totalSteps: 3)
        XCTAssertEqual(overstepped.currentStep, 2)
        
        let negative = OnboardingCoordinator(initialStep: -5, totalSteps: 3)
        XCTAssertEqual(negative.currentStep, 0)
        
        let empty = OnboardingCoordinator(initialStep: 0, totalSteps: 0)
        XCTAssertEqual(empty.currentStep, 0)
        XCTAssertEqual(empty.totalSteps, 0)
        XCTAssertEqual(empty.progress, 0.0)
    }
    
    func testCoordinatorNavigation() {
        var stepChanges: [(Int, Int)] = []
        var didComplete = false
        
        let coordinator = OnboardingCoordinator(
            initialStep: 0,
            totalSteps: 3,
            onStepChange: { from, to in
                stepChanges.append((from, to))
            },
            onComplete: {
                didComplete = true
            }
        )
        
        // Move to step 1
        coordinator.next()
        XCTAssertEqual(coordinator.currentStep, 1)
        XCTAssertFalse(coordinator.isFirstStep)
        XCTAssertFalse(coordinator.isLastStep)
        XCTAssertEqual(coordinator.progress, 2.0 / 3.0, accuracy: 0.001)
        
        // Move to step 2 (last step)
        coordinator.next()
        XCTAssertEqual(coordinator.currentStep, 2)
        XCTAssertTrue(coordinator.isLastStep)
        XCTAssertEqual(coordinator.progress, 1.0, accuracy: 0.001)
        XCTAssertFalse(didComplete)
        
        // Calling next on last step triggers complete
        coordinator.next()
        XCTAssertTrue(didComplete)
        
        // Step changes recorded
        XCTAssertEqual(stepChanges.count, 2)
        XCTAssertEqual(stepChanges[0].0, 0)
        XCTAssertEqual(stepChanges[0].1, 1)
        XCTAssertEqual(stepChanges[1].0, 1)
        XCTAssertEqual(stepChanges[1].1, 2)
    }
    
    func testCoordinatorPreviousAndGoTo() {
        let coordinator = OnboardingCoordinator(initialStep: 2, totalSteps: 5)
        
        coordinator.previous()
        XCTAssertEqual(coordinator.currentStep, 1)
        
        coordinator.goTo(step: 4)
        XCTAssertEqual(coordinator.currentStep, 4)
        XCTAssertTrue(coordinator.isLastStep)
        
        // Go beyond bounds
        coordinator.goTo(step: 99)
        XCTAssertEqual(coordinator.currentStep, 4)
        
        coordinator.goTo(step: -10)
        XCTAssertEqual(coordinator.currentStep, 0)
        XCTAssertTrue(coordinator.isFirstStep)
    }
    
    func testCoordinatorSkipBehavior() {
        var didSkip = false
        var didComplete = false
        
        let coordinator = OnboardingCoordinator(
            initialStep: 0,
            totalSteps: 3,
            onComplete: { didComplete = true },
            onSkip: { didSkip = true }
        )
        
        coordinator.skip()
        XCTAssertTrue(didSkip)
        XCTAssertFalse(didComplete)
        
        // Default skip without onSkip falls back to complete
        var fallbackComplete = false
        let fallbackCoordinator = OnboardingCoordinator(
            initialStep: 0,
            totalSteps: 3,
            onComplete: { fallbackComplete = true }
        )
        fallbackCoordinator.skip()
        XCTAssertTrue(fallbackComplete)
    }
    
    // MARK: - OnboardingManager Tests
    
    func testManagerCompletionFlag() {
        let key = "test_onboarding_key"
        XCTAssertFalse(OnboardingManager.hasCompletedOnboarding(key: key, userDefaults: testUserDefaults))
        
        OnboardingManager.setCompletedOnboarding(true, key: key, userDefaults: testUserDefaults)
        XCTAssertTrue(OnboardingManager.hasCompletedOnboarding(key: key, userDefaults: testUserDefaults))
        
        OnboardingManager.setCompletedOnboarding(false, key: key, userDefaults: testUserDefaults)
        XCTAssertFalse(OnboardingManager.hasCompletedOnboarding(key: key, userDefaults: testUserDefaults))
    }
    
    func testManagerVersionBasedPresentation() {
        let versionKey = "test_version_key"
        let completionKey = "test_comp_key"
        
        // 1. Never completed before -> should show
        XCTAssertTrue(
            OnboardingManager.shouldShowOnboarding(
                forVersion: "1.2.0",
                versionKey: versionKey,
                userDefaults: testUserDefaults
            )
        )
        
        // 2. Record completion for 1.2.0
        OnboardingManager.recordOnboardingCompleted(
            forVersion: "1.2.0",
            versionKey: versionKey,
            completionKey: completionKey,
            userDefaults: testUserDefaults
        )
        
        XCTAssertTrue(OnboardingManager.hasCompletedOnboarding(key: completionKey, userDefaults: testUserDefaults))
        
        // 3. Check for same version -> should NOT show
        XCTAssertFalse(
            OnboardingManager.shouldShowOnboarding(
                forVersion: "1.2.0",
                versionKey: versionKey,
                userDefaults: testUserDefaults
            )
        )
        
        // 4. Check for older version -> should NOT show
        XCTAssertFalse(
            OnboardingManager.shouldShowOnboarding(
                forVersion: "1.1.0",
                versionKey: versionKey,
                userDefaults: testUserDefaults
            )
        )
        
        // 5. Check for newer version -> should show
        XCTAssertTrue(
            OnboardingManager.shouldShowOnboarding(
                forVersion: "2.0.0",
                versionKey: versionKey,
                userDefaults: testUserDefaults
            )
        )
        
        // 6. Reset
        OnboardingManager.reset(
            completionKey: completionKey,
            versionKey: versionKey,
            userDefaults: testUserDefaults
        )
        XCTAssertFalse(OnboardingManager.hasCompletedOnboarding(key: completionKey, userDefaults: testUserDefaults))
        XCTAssertTrue(
            OnboardingManager.shouldShowOnboarding(
                forVersion: "1.2.0",
                versionKey: versionKey,
                userDefaults: testUserDefaults
            )
        )
    }
    
    // MARK: - UI Component View Construction Tests
    
    func testIndicatorClamping() {
        let indicator = OnboardingPageIndicator(
            totalCount: 5,
            currentIndex: 2
        )
        XCTAssertEqual(indicator.totalCount, 5)
        XCTAssertEqual(indicator.currentIndex, 2)
        
        let outOfBoundsIndicator = OnboardingPageIndicator(
            totalCount: 3,
            currentIndex: 99
        )
        XCTAssertEqual(outOfBoundsIndicator.currentIndex, 2)
    }
}
