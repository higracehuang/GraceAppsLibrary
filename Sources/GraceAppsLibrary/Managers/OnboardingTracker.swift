import Foundation

/// Defines a provider capable of logging or sending onboarding telemetry events.
public protocol OnboardingAnalyticsProvider: Sendable {
    /// Dispatches a telemetry event with associated parameters.
    func track(event: String, parameters: [String: String])
}

/// A privacy-first, lightweight telemetry tracker for onboarding funnel metrics.
/// Supports plugging in TelemetryDeck, local debugging loggers, or other privacy-preserving backends via `OnboardingAnalyticsProvider`.
public final class OnboardingTracker: @unchecked Sendable {
    public static let shared = OnboardingTracker()
    
    private let lock = NSLock()
    private var provider: OnboardingAnalyticsProvider?
    private var flowStartTime: Date?
    private var stepStartTime: Date?
    private var currentStepIndex: Int = 0
    
    public init() {}
    
    /// Configures the active analytics provider.
    public func configure(provider: OnboardingAnalyticsProvider?) {
        lock.lock()
        defer { lock.unlock() }
        self.provider = provider
    }
    
    /// Tracks when the onboarding flow starts.
    public func trackStarted(appVersion: String, entryPoint: String = "first_launch") {
        lock.lock()
        let now = Date()
        flowStartTime = now
        stepStartTime = now
        currentStepIndex = 0
        let activeProvider = provider
        lock.unlock()
        
        activeProvider?.track(event: "onboarding_started", parameters: [
            "app_version": appVersion,
            "entry_point": entryPoint
        ])
    }
    
    /// Tracks when a specific onboarding step/slide becomes visible to the user.
    public func trackStepViewed(index: Int, name: String) {
        lock.lock()
        let now = Date()
        let totalElapsed = flowStartTime.map { Int(now.timeIntervalSince($0)) } ?? 0
        currentStepIndex = index
        stepStartTime = now
        let activeProvider = provider
        lock.unlock()
        
        activeProvider?.track(event: "onboarding_step_viewed", parameters: [
            "step_index": "\(index)",
            "step_name": name,
            "total_elapsed_sec": "\(totalElapsed)"
        ])
    }
    
    /// Tracks user interaction with micro-commitment cues (pledges, goal selections, interactive choices).
    public func trackMicroCommitment(type: String, value: String, stepIndex: Int? = nil) {
        lock.lock()
        let idx = stepIndex ?? currentStepIndex
        let activeProvider = provider
        lock.unlock()
        
        activeProvider?.track(event: "onboarding_micro_commitment", parameters: [
            "commitment_type": type,
            "commitment_value": value,
            "step_index": "\(idx)"
        ])
    }
    
    /// Tracks when a user skips an optional step.
    public func trackStepSkipped(index: Int, name: String) {
        lock.lock()
        let activeProvider = provider
        lock.unlock()
        
        activeProvider?.track(event: "onboarding_step_skipped", parameters: [
            "step_index": "\(index)",
            "step_name": name
        ])
    }
    
    /// Tracks when the onboarding paywall or upgrade slide is presented.
    public func trackPaywallViewed(source: String = "onboarding_flow", offeringId: String? = nil) {
        lock.lock()
        let now = Date()
        let totalElapsed = flowStartTime.map { Int(now.timeIntervalSince($0)) } ?? 0
        let activeProvider = provider
        lock.unlock()
        
        var params: [String: String] = [
            "source": source,
            "total_elapsed_sec": "\(totalElapsed)"
        ]
        if let offeringId = offeringId {
            params["offering_id"] = offeringId
        }
        
        activeProvider?.track(event: "onboarding_paywall_viewed", parameters: params)
    }
    
    /// Tracks successful completion of the onboarding flow.
    public func trackCompleted(didPerformAction: Bool = true, finalStepIndex: Int? = nil) {
        lock.lock()
        let now = Date()
        let totalDuration = flowStartTime.map { Int(now.timeIntervalSince($0)) } ?? 0
        let idx = finalStepIndex ?? currentStepIndex
        let activeProvider = provider
        // Reset timers
        flowStartTime = nil
        stepStartTime = nil
        lock.unlock()
        
        activeProvider?.track(event: "onboarding_completed", parameters: [
            "total_duration_sec": "\(totalDuration)",
            "did_perform_action": "\(didPerformAction)",
            "final_step_index": "\(idx)"
        ])
    }
}
