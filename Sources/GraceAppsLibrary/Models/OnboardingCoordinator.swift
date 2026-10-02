import Foundation
import Combine

/// Coordinator managing onboarding step navigation, completion state, and transition callbacks.
public final class OnboardingCoordinator: ObservableObject {
    @Published public var currentStep: Int {
        didSet {
            if oldValue != currentStep {
                onStepChange?(oldValue, currentStep)
            }
        }
    }
    
    @Published public var totalSteps: Int
    
    /// Optional callback invoked whenever the current step index changes: `(fromStep, toStep)`.
    public var onStepChange: ((_ from: Int, _ to: Int) -> Void)?
    
    /// Optional callback invoked when the onboarding flow finishes or the final step completes.
    public var onComplete: (() -> Void)?
    
    /// Optional callback invoked when the user chooses to skip onboarding.
    public var onSkip: (() -> Void)?
    
    public init(
        initialStep: Int = 0,
        totalSteps: Int,
        onStepChange: ((_ from: Int, _ to: Int) -> Void)? = nil,
        onComplete: (() -> Void)? = nil,
        onSkip: (() -> Void)? = nil
    ) {
        self.currentStep = max(0, min(initialStep, max(0, totalSteps - 1)))
        self.totalSteps = max(0, totalSteps)
        self.onStepChange = onStepChange
        self.onComplete = onComplete
        self.onSkip = onSkip
    }
    
    /// Returns `true` if current step is the very first step (0).
    public var isFirstStep: Bool {
        currentStep == 0
    }
    
    /// Returns `true` if current step is the last step.
    public var isLastStep: Bool {
        totalSteps > 0 && currentStep == (totalSteps - 1)
    }
    
    /// Fraction of progress through onboarding from 0.0 to 1.0.
    public var progress: Double {
        guard totalSteps > 0 else { return 0.0 }
        return Double(currentStep + 1) / Double(totalSteps)
    }
    
    /// Advances to the next step, or triggers `complete()` if already on the last step.
    public func next() {
        guard totalSteps > 0 else { return }
        if currentStep < totalSteps - 1 {
            currentStep += 1
        } else {
            complete()
        }
    }
    
    /// Goes back to the previous step if not on the first step.
    public func previous() {
        if currentStep > 0 {
            currentStep -= 1
        }
    }
    
    /// Navigates directly to a target step within bounds.
    public func goTo(step: Int) {
        guard totalSteps > 0 else { return }
        let clamped = max(0, min(step, totalSteps - 1))
        currentStep = clamped
    }
    
    /// Triggers the skip handler if provided, or defaults to calling `complete()`.
    public func skip() {
        if let onSkip = onSkip {
            onSkip()
        } else {
            complete()
        }
    }
    
    /// Triggers the completion callback.
    public func complete() {
        onComplete?()
    }
}
