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
    
    func testProgressBarClamping() {
        let normalBar = OnboardingProgressBar(progress: 0.5)
        XCTAssertEqual(normalBar.progress, 0.5, accuracy: 0.001)
        
        let overBar = OnboardingProgressBar(progress: 1.5)
        XCTAssertEqual(overBar.progress, 1.0, accuracy: 0.001)
        
        let underBar = OnboardingProgressBar(progress: -0.2)
        XCTAssertEqual(underBar.progress, 0.0, accuracy: 0.001)
    }
    
    func testSegmentedProgressBarClamping() {
        let segmentedBar = OnboardingSegmentedProgressBar(
            totalSteps: 5,
            currentStep: 2
        )
        XCTAssertEqual(segmentedBar.totalSteps, 5)
        XCTAssertEqual(segmentedBar.currentStep, 2)
        
        let outOfBoundsSegmented = OnboardingSegmentedProgressBar(
            totalSteps: 3,
            currentStep: 10
        )
        XCTAssertEqual(outOfBoundsSegmented.currentStep, 2)
    }
    
    // MARK: - OnboardingTracker Tests
    
    final class MockAnalyticsProvider: OnboardingAnalyticsProvider, @unchecked Sendable {
        var recordedEvents: [(event: String, parameters: [String: String])] = []
        
        func track(event: String, parameters: [String: String]) {
            recordedEvents.append((event, parameters))
        }
    }
    
    func testOnboardingTrackerFlow() {
        let tracker = OnboardingTracker()
        let mock = MockAnalyticsProvider()
        tracker.configure(provider: mock)
        
        // 1. Start flow
        tracker.trackStarted(appVersion: "1.0.0", entryPoint: "first_install")
        XCTAssertEqual(mock.recordedEvents.count, 1)
        XCTAssertEqual(mock.recordedEvents.first?.event, "onboarding_started")
        XCTAssertEqual(mock.recordedEvents.first?.parameters["app_version"], "1.0.0")
        XCTAssertEqual(mock.recordedEvents.first?.parameters["entry_point"], "first_install")
        
        // 2. Step 1 View
        tracker.trackStepViewed(index: 0, name: "Welcome")
        XCTAssertEqual(mock.recordedEvents.count, 2)
        XCTAssertEqual(mock.recordedEvents[1].event, "onboarding_step_viewed")
        XCTAssertEqual(mock.recordedEvents[1].parameters["step_index"], "0")
        XCTAssertEqual(mock.recordedEvents[1].parameters["step_name"], "Welcome")
        
        // 3. Micro-commitment
        tracker.trackMicroCommitment(type: "pledge_tapped", value: "daily_brew")
        XCTAssertEqual(mock.recordedEvents.count, 3)
        XCTAssertEqual(mock.recordedEvents[2].event, "onboarding_micro_commitment")
        XCTAssertEqual(mock.recordedEvents[2].parameters["commitment_type"], "pledge_tapped")
        XCTAssertEqual(mock.recordedEvents[2].parameters["commitment_value"], "daily_brew")
        
        // 4. Step 2 Skip
        tracker.trackStepSkipped(index: 1, name: "Preferences")
        XCTAssertEqual(mock.recordedEvents.count, 4)
        XCTAssertEqual(mock.recordedEvents[3].event, "onboarding_step_skipped")
        XCTAssertEqual(mock.recordedEvents[3].parameters["step_index"], "1")
        
        // 5. Paywall View
        tracker.trackPaywallViewed(source: "onboarding_flow", offeringId: "pro_annual")
        XCTAssertEqual(mock.recordedEvents.count, 5)
        XCTAssertEqual(mock.recordedEvents[4].event, "onboarding_paywall_viewed")
        XCTAssertEqual(mock.recordedEvents[4].parameters["offering_id"], "pro_annual")
        
        // 6. Complete
        tracker.trackCompleted(didPerformAction: true, finalStepIndex: 2)
        XCTAssertEqual(mock.recordedEvents.count, 6)
        XCTAssertEqual(mock.recordedEvents[5].event, "onboarding_completed")
        XCTAssertEqual(mock.recordedEvents[5].parameters["did_perform_action"], "true")
        XCTAssertEqual(mock.recordedEvents[5].parameters["final_step_index"], "2")
    }
}

