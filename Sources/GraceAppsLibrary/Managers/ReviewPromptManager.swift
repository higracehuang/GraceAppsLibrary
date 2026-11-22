//
//  ReviewPromptManager.swift
//  GraceAppsLibrary
//

import Foundation
import StoreKit
import UIKit
import SwiftUI

/// Purely generic representation of a positive value moment in any Grace app.
public struct PositiveValueMoment: RawRepresentable, Equatable, Hashable, ExpressibleByStringLiteral, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public static let genericMoment = PositiveValueMoment(rawValue: "positive_value_moment")
    public static let milestoneReached = PositiveValueMoment(rawValue: "milestone_reached")
}

/// Presentation style for the rating prompt.
public enum ReviewPromptStyle: Sendable {
    /// Frictionless 1-step direct native StoreKit prompt (maximizes rating volume).
    case directNative
    /// 2-step alert asking "Are you enjoying [App]?" before triggering StoreKit or feedback.
    case intermediateAlert
}

/// Turnkey configuration for review prompt scheduling, cooldown, and quota protection.
public struct ReviewPromptConfig: Sendable {
    public var style: ReviewPromptStyle
    public var minDaysBetweenPrompts: Int
    public var minActiveDays: Int
    public var minMilestoneEvents: Int
    public var ignorePatchVersions: Bool

    public init(
        style: ReviewPromptStyle = .directNative,
        minDaysBetweenPrompts: Int = 90,
        minActiveDays: Int = 3,
        minMilestoneEvents: Int = 5,
        ignorePatchVersions: Bool = true
    ) {
        self.style = style
        self.minDaysBetweenPrompts = minDaysBetweenPrompts
        self.minActiveDays = minActiveDays
        self.minMilestoneEvents = minMilestoneEvents
        self.ignorePatchVersions = ignorePatchVersions
    }
}

@MainActor
public final class ReviewPromptManager {

    public static let shared = ReviewPromptManager()

    public var config: ReviewPromptConfig = ReviewPromptConfig()

    public init(config: ReviewPromptConfig = ReviewPromptConfig()) {
        self.config = config
    }

    /// Backward-compatible initializer
    public convenience init(checkpointCount: Int, config: ReviewPromptConfig = ReviewPromptConfig()) {
        self.init(config: config)
    }

    public func configure(_ config: ReviewPromptConfig) {
        self.config = config
    }

    /// Retained overlay window used to present the review pre-filter alert independently of any
    /// dismissing or presenting sheets/modals in the application view hierarchy.
    private var alertWindow: UIWindow?
    
    private struct SettingKeys {
        static let lastVersionPromptedForReviewKey = "GraceApps_Review_LastVersionPromptedForReview"
        static let appVersionForStorageKey = "GraceApps_Review_AppVersionForStorage"
        static let lastDailyCheckDateKey = "GraceApps_Review_LastDailyCheckDate"
        static let lastPromptDateKey = "GraceApps_Review_LastPromptDate"
        static let activeDaysCountKey = "GraceApps_Review_ActiveDaysCount"
        static let lastActiveDateKey = "GraceApps_Review_LastActiveDate"
        static let milestoneCountKey = "GraceApps_Review_MilestoneCount"
        static let lastMilestoneNameKey = "GraceApps_Review_LastMilestoneName"
        static let lastMilestoneDateKey = "GraceApps_Review_LastMilestoneDate"
    }

    private var appName: String {
        Bundle.main.appName
    }

    private var releaseVersionNumber: String {
        Bundle.main.releaseVersionNumber
    }

    /// Returns the major.minor segment of a version string (e.g. "2.1.0" -> "2.1").
    public static func majorMinorVersion(from version: String) -> String {
        let parts = version.split(separator: ".")
        if parts.count >= 2 {
            return "\(parts[0]).\(parts[1])"
        }
        return version
    }

    /// Whether the minimum cooldown period between review prompts has passed.
    public func hasPassedCooldown(now: Date = Date()) -> Bool {
        guard config.minDaysBetweenPrompts > 0 else { return true }
        guard let lastDate = UserDefaults.standard.object(forKey: SettingKeys.lastPromptDateKey) as? Date else {
            return true
        }
        let elapsedSeconds = now.timeIntervalSince(lastDate)
        let minSeconds = Double(config.minDaysBetweenPrompts) * 86400.0
        return elapsedSeconds >= minSeconds
    }

    /// The number of distinct active days recorded.
    public var activeDaysCount: Int {
        UserDefaults.standard.integer(forKey: SettingKeys.activeDaysCountKey)
    }

    /// The number of milestone events recorded.
    public var milestoneCount: Int {
        UserDefaults.standard.integer(forKey: SettingKeys.milestoneCountKey)
    }

    /// The date when the user was last prompted for review, if any.
    public var lastPromptDate: Date? {
        UserDefaults.standard.object(forKey: SettingKeys.lastPromptDateKey) as? Date
    }

    /// The app release version string that was last prompted for review, if any.
    public var lastVersionPrompted: String? {
        UserDefaults.standard.string(forKey: SettingKeys.lastVersionPromptedForReviewKey)
    }

    /// The name of the most recently recorded milestone event, if any.
    public var lastMilestoneName: String? {
        UserDefaults.standard.string(forKey: SettingKeys.lastMilestoneNameKey)
    }

    /// The date when the most recent milestone event was recorded, if any.
    public var lastMilestoneDate: Date? {
        UserDefaults.standard.object(forKey: SettingKeys.lastMilestoneDateKey) as? Date
    }

    /// Records an active calendar day session for value gating.
    /// Internal only: invoked automatically via `ReviewPromptManager.appInit()`.
    internal func recordDailySession(now: Date = Date()) {
        let calendar = Calendar.current
        let lastActiveDate = UserDefaults.standard.object(forKey: SettingKeys.lastActiveDateKey) as? Date
        if lastActiveDate == nil || !calendar.isDate(now, inSameDayAs: lastActiveDate!) {
            let days = UserDefaults.standard.integer(forKey: SettingKeys.activeDaysCountKey) + 1
            UserDefaults.standard.set(days, forKey: SettingKeys.activeDaysCountKey)
            UserDefaults.standard.set(now, forKey: SettingKeys.lastActiveDateKey)
            GraceLogger.info("Recorded active day: \(days)", category: .review)
        }
    }

    /// Records a milestone action event.
    public func recordMilestoneEvent(_ name: String = "milestone") {
        let count = UserDefaults.standard.integer(forKey: SettingKeys.milestoneCountKey) + 1
        UserDefaults.standard.set(count, forKey: SettingKeys.milestoneCountKey)
        UserDefaults.standard.set(name, forKey: SettingKeys.lastMilestoneNameKey)
        UserDefaults.standard.set(Date(), forKey: SettingKeys.lastMilestoneDateKey)
        GraceLogger.info("Recorded milestone event '\(name)' (total: \(count))", category: .review)
    }

    /// Whether the user has demonstrated sufficient depth/value before prompting.
    public func hasMetValueThreshold() -> Bool {
        let activeDays = activeDaysCount
        let milestones = milestoneCount

        return activeDays >= config.minActiveDays ||
               milestones >= config.minMilestoneEvents
    }

    /// Comprehensive check evaluating all eligibility gates (release notes, cooldown, version).
    public func isEligibleForPrompt(now: Date = Date()) -> Bool {
        guard !ReleaseNotesManager.hasShownReleaseNotesThisSession else {
            GraceLogger.info("Review prompt suppressed: release notes already shown this session.", category: .review)
            return false
        }
        guard hasPassedCooldown(now: now) else {
            GraceLogger.info("Review prompt suppressed: cooldown of \(config.minDaysBetweenPrompts) days not elapsed.", category: .review)
            return false
        }
        guard !hasPromptedForCurrentVersion else {
            GraceLogger.info("Review prompt suppressed: current version already prompted.", category: .review)
            return false
        }
        return true
    }

    private func shouldPrompt(now: Date = Date()) -> Bool {
        guard isEligibleForPrompt(now: now) else { return false }
        let result = hasMetValueThreshold()
        GraceLogger.info("Evaluate shouldPrompt: valueThresholdMet=\(result) -> \(result ? "SHOULD PROMPT" : "SKIP")", category: .review)
        return result
    }

    /// Requests review if conditions are met, presenting via the configured style (`.directNative` or `.intermediateAlert`).
    public func requestReview(onNegativeFeedback: (() -> Void)? = nil) {
        requestReviewIfEligible(onNegativeFeedback: onNegativeFeedback)
    }

    /// Requests review if conditions are met, returning whether prompt was shown.
    /// Internal only: external callers should use `UXAction.ratingPrompt` via `UXFlowOrchestrator`.
    @discardableResult
    internal func requestReviewIfNecessary(onNegativeFeedback: (() -> Void)? = nil) -> Bool {
        GraceLogger.info("requestReviewIfNecessary() invoked", category: .review)
        if shouldPrompt() {
            switch config.style {
            case .directNative:
                showNativeReviewPrompt()
            case .intermediateAlert:
                askForReview(onPositive: showNativeReviewPrompt, onNegative: onNegativeFeedback)
            }
            return true
        }
        return false
    }

    /// Evaluates eligibility and presents the review prompt with the requested style.
    /// Internal only: external callers should use `UXAction.ratingPrompt` via `UXFlowOrchestrator`.
    @discardableResult
    internal func requestReviewIfEligible(
        style: ReviewPromptStyle? = nil,
        now: Date = Date(),
        onNegativeFeedback: (() -> Void)? = nil
    ) -> Bool {
        guard isEligibleForPrompt(now: now) else { return false }
        guard hasMetValueThreshold() else {
            GraceLogger.info("Review prompt suppressed: value threshold not met.", category: .review)
            return false
        }

        let effectiveStyle = style ?? config.style
        switch effectiveStyle {
        case .directNative:
            showNativeReviewPrompt()
        case .intermediateAlert:
            askForReview(onPositive: showNativeReviewPrompt, onNegative: onNegativeFeedback)
        }
        return true
    }

    /// Convenience to evaluate eligibility and trigger 1-step direct native StoreKit prompt.
    @discardableResult
    internal func requestDirectReviewIfEligible(now: Date = Date()) -> Bool {
        requestReviewIfEligible(style: .directNative, now: now)
    }

    /// Convenience to evaluate eligibility and trigger 2-step intermediate alert prompt.
    @discardableResult
    public func requestAlertReviewIfEligible(
        now: Date = Date(),
        onNegativeFeedback: (() -> Void)? = nil
    ) -> Bool {
        requestReviewIfEligible(style: .intermediateAlert, now: now, onNegativeFeedback: onNegativeFeedback)
    }

    @discardableResult
    internal static func requestReviewIfEligible(
        style: ReviewPromptStyle? = nil,
        onNegativeFeedback: (() -> Void)? = nil
    ) -> Bool {
        shared.requestReviewIfEligible(style: style, onNegativeFeedback: onNegativeFeedback)
    }

    @discardableResult
    internal static func requestDirectReviewIfEligible() -> Bool {
        shared.requestDirectReviewIfEligible()
    }

    @discardableResult
    public static func requestAlertReviewIfEligible(onNegativeFeedback: (() -> Void)? = nil) -> Bool {
        shared.requestAlertReviewIfEligible(onNegativeFeedback: onNegativeFeedback)
    }

    /// Triggers review request daily throttled.
    public func requestReviewDaily(onNegativeFeedback: (() -> Void)? = nil) {
        let lastDate = UserDefaults.standard.object(forKey: SettingKeys.lastDailyCheckDateKey) as? Date
        if lastDate == nil || !Calendar.current.isDateInToday(lastDate!) {
            GraceLogger.info("Daily review check passed. Requesting review...", category: .review)
            UserDefaults.standard.set(Date(), forKey: SettingKeys.lastDailyCheckDateKey)
            self.requestReview(onNegativeFeedback: onNegativeFeedback)
        } else {
            GraceLogger.info("Daily review check throttled (already checked today).", category: .review)
        }
    }

    /// Directly presents native StoreKit review prompt without intermediate pre-filter alert.
    public func requestDirectNativeReview() {
        GraceLogger.info("Direct native review requested.", category: .review)
        showNativeReviewPrompt()
    }

    /// Evaluates eligibility and presents direct native StoreKit review prompt after a short delay.
    ///
    /// - Parameters:
    ///   - currentCount: The current count of positive engagements or data points.
    ///   - threshold: Target threshold count to qualify (defaults to 2).
    ///   - isModalPresented: Optional flag to suppress prompting if a modal (e.g. paywall) is currently visible.
    ///   - delay: Seconds to delay before presenting StoreKit prompt to allow transitions to settle (default is 0.6s).
    @discardableResult
    internal func requestDirectReviewIfEligible(
        currentCount: Int,
        threshold: Int = 2,
        isModalPresented: Bool = false,
        delay: Double = 0.6
    ) -> Bool {
        guard !isModalPresented else {
            GraceLogger.info("Direct review skipped: modal is currently presented.", category: .review)
            return false
        }
        guard !ReleaseNotesManager.hasShownReleaseNotesThisSession else {
            GraceLogger.info("Direct review skipped: release notes already shown this session.", category: .review)
            return false
        }
        guard !hasPromptYet() else {
            GraceLogger.info("Direct review skipped: current version already prompted.", category: .review)
            return false
        }
        guard currentCount >= threshold else {
            GraceLogger.info("Direct review skipped: count (\(currentCount)) below threshold (\(threshold)).", category: .review)
            return false
        }

        GraceLogger.success("Direct review eligible (count=\(currentCount), threshold=\(threshold)). Scheduling in \(delay)s...", category: .review)

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            guard !self.hasPromptYet() else { return }
            guard !ReleaseNotesManager.hasShownReleaseNotesThisSession else { return }

            self.requestDirectNativeReview()
        }

        return true
    }

    /// Static helper to evaluate eligibility and present direct native StoreKit review prompt.
    @discardableResult
    internal static func requestDirectReviewIfEligible(
        currentCount: Int,
        threshold: Int = 2,
        isModalPresented: Bool = false,
        delay: Double = 0.6
    ) -> Bool {
        shared.requestDirectReviewIfEligible(
            currentCount: currentCount,
            threshold: threshold,
            isModalPresented: isModalPresented,
            delay: delay
        )
    }

    /// Directly presents the GAL 2-step review prompt (alert) for testing and QA.
    public func debugPresentReviewPrompt(onNegativeFeedback: (() -> Void)? = nil) {
        GraceLogger.info("Debug forced GAL 2-step review prompt presentation.", category: .debug)
        askForReview(onPositive: showNativeReviewPrompt, onNegative: onNegativeFeedback)
    }

    /// Static helper to directly present the GAL 2-step review prompt.
    public static func debugPresentReviewPrompt(onNegativeFeedback: (() -> Void)? = nil) {
        shared.debugPresentReviewPrompt(onNegativeFeedback: onNegativeFeedback)
    }

    /// Records a positive value moment by string event identifier (defaults to "positive_value_moment").
    /// Prompts for App Store review if the current version has not been prompted yet and no release notes were shown this session.
    /// Never gates app features or provides rewards/incentives for ratings.
    @discardableResult
    internal func recordPositiveValueMoment(
        _ eventName: String = "positive_value_moment",
        onNegativeFeedback: (() -> Void)? = nil
    ) -> Bool {
        GraceLogger.info("Positive value moment recorded: '\(eventName)'", category: .review)

        let key = "GraceApps_Review_EventCount_\(eventName)"
        let newCount = UserDefaults.standard.integer(forKey: key) + 1
        UserDefaults.standard.set(newCount, forKey: key)
        recordMilestoneEvent(eventName)

        guard !ReleaseNotesManager.hasShownReleaseNotesThisSession else {
            GraceLogger.info("Positive value moment '\(eventName)' recorded, but release notes were already shown in this session. Suppressing review prompt.", category: .review)
            return false
        }

        guard hasPassedCooldown() else {
            GraceLogger.info("Positive value moment '\(eventName)' recorded, but cooldown has not elapsed.", category: .review)
            return false
        }

        guard !hasPromptYet() else {
            GraceLogger.info("Positive value moment '\(eventName)' recorded, but version '\(releaseVersionNumber)' was already prompted. Skipping prompt.", category: .review)
            return false
        }

        GraceLogger.success("Positive value moment achieved ('\(eventName)'). Presenting review prompt...", category: .review)
        switch config.style {
        case .directNative:
            showNativeReviewPrompt()
        case .intermediateAlert:
            askForReview(onPositive: showNativeReviewPrompt, onNegative: onNegativeFeedback)
        }
        return true
    }

    /// Overload for PositiveValueMoment struct.
    @discardableResult
    internal func recordPositiveValueMoment(
        _ moment: PositiveValueMoment,
        onNegativeFeedback: (() -> Void)? = nil
    ) -> Bool {
        recordPositiveValueMoment(moment.rawValue, onNegativeFeedback: onNegativeFeedback)
    }

    /// Alias for requestReviewIfPositiveValueMoment.
    @discardableResult
    internal func requestReviewIfPositiveValueMoment(
        _ eventName: String = "positive_value_moment",
        onNegativeFeedback: (() -> Void)? = nil
    ) -> Bool {
        recordPositiveValueMoment(eventName, onNegativeFeedback: onNegativeFeedback)
    }

    /// Records a milestone action with current count and target threshold.
    /// Prompts for review when count >= threshold and version has not been prompted yet.
    @discardableResult
    internal func recordMilestone(
        count: Int,
        threshold: Int = 2,
        name: String = "milestone",
        onNegativeFeedback: (() -> Void)? = nil
    ) -> Bool {
        GraceLogger.info("Milestone '\(name)' evaluated: count=\(count), threshold=\(threshold)", category: .review)
        guard count >= threshold else {
            GraceLogger.info("Milestone '\(name)' count (\(count)) is below threshold (\(threshold)). Skipping prompt.", category: .review)
            return false
        }
        return recordPositiveValueMoment(name, onNegativeFeedback: onNegativeFeedback)
    }

    /// Resets all review prompt state, cooldowns, active days, and milestones.
    /// Dedicated for unit and UI testing environments.
    public func resetForTesting() {
        dismissAlertWindow()
        ReleaseNotesManager.hasShownReleaseNotesThisSession = false
        UserDefaults.standard.removeObject(forKey: SettingKeys.lastVersionPromptedForReviewKey)
        UserDefaults.standard.removeObject(forKey: SettingKeys.lastPromptDateKey)
        UserDefaults.standard.removeObject(forKey: SettingKeys.activeDaysCountKey)
        UserDefaults.standard.removeObject(forKey: SettingKeys.lastActiveDateKey)
        UserDefaults.standard.removeObject(forKey: SettingKeys.milestoneCountKey)
        UserDefaults.standard.removeObject(forKey: SettingKeys.lastMilestoneNameKey)
        UserDefaults.standard.removeObject(forKey: SettingKeys.lastMilestoneDateKey)
        UserDefaults.standard.removeObject(forKey: SettingKeys.lastDailyCheckDateKey)
        UserDefaults.standard.removeObject(forKey: "GraceApps_Review_LastEngagementDate")
        for key in UserDefaults.standard.dictionaryRepresentation().keys {
            if key.hasPrefix("GraceApps_Review_EventCount_") || key.hasPrefix("GraceApps_Review_MomentCount_") {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        GraceLogger.info("Reset review prompt state for testing.", category: .debug)
    }

    /// Suppresses review prompts by marking the specified or current release version as already prompted.
    /// Dedicated for UI tests or test harnesses that need to prevent prompts from interrupting automation.
    public func suppressForTesting(version: String? = nil) {
        let targetVersion = version ?? releaseVersionNumber
        UserDefaults.standard.set(targetVersion, forKey: SettingKeys.lastVersionPromptedForReviewKey)
        GraceLogger.info("Suppressed review prompt for testing (version: '\(targetVersion)').", category: .debug)
    }

    /// Static convenience to reset all review prompt state for testing.
    public static func resetForTesting() {
        shared.resetForTesting()
    }

    /// Static convenience to suppress review prompts for testing.
    public static func suppressForTesting(version: String? = nil) {
        shared.suppressForTesting(version: version)
    }

    /// Backward-compatible alias for `resetForTesting()`.
    public static func debugResetReviewState() {
        shared.resetForTesting()
    }

    public static func appInit() {
        shared.recordDailySession()
        let storedVersion = UserDefaults.standard.string(forKey: SettingKeys.appVersionForStorageKey) ?? ""
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""

        if storedVersion != currentVersion {
            let isPatch = shared.config.ignorePatchVersions &&
                !storedVersion.isEmpty &&
                !currentVersion.isEmpty &&
                majorMinorVersion(from: storedVersion) == majorMinorVersion(from: currentVersion)

            if isPatch {
                GraceLogger.info("App patch version updated ('\(storedVersion)' -> '\(currentVersion)'). Retaining review state.", category: .app)
            } else {
                GraceLogger.info("App version changed ('\(storedVersion)' -> '\(currentVersion)'). Resetting milestone counter.", category: .app)
                UserDefaults.standard.set(0, forKey: SettingKeys.milestoneCountKey)
            }
            UserDefaults.standard.set(currentVersion, forKey: SettingKeys.appVersionForStorageKey)
        } else {
            GraceLogger.info("App initialized for version '\(currentVersion)'.", category: .app)
        }
    }

    /// Whether the current release version (or major.minor if ignorePatchVersions is true) has already been prompted for review.
    public var hasPromptedForCurrentVersion: Bool {
        hasPromptYet()
    }

    public func hasPromptYet() -> Bool {
        guard let lastVersionPrompted = UserDefaults.standard.string(forKey: SettingKeys.lastVersionPromptedForReviewKey),
              !lastVersionPrompted.isEmpty else {
            return false
        }
        if config.ignorePatchVersions {
            return Self.majorMinorVersion(from: lastVersionPrompted) == Self.majorMinorVersion(from: releaseVersionNumber)
        } else {
            return lastVersionPrompted == releaseVersionNumber
        }
    }

    nonisolated public static func getReviewURL(appStoreId: String) -> URL? {
        let cleanId = appStoreId.hasPrefix("id") ? appStoreId : "id\(appStoreId)"
        return URL(string: "https://apps.apple.com/app/\(cleanId)?action=write-review")
    }

    /// Opens the App Store page directly to the Write a Review form.
    @discardableResult
    @MainActor
    public static func openAppStoreReviewPage(appStoreId: String) -> Bool {
        guard let url = getReviewURL(appStoreId: appStoreId) else { return false }
        GraceLogger.info("Opening App Store write-review URL: \(url)", category: .review)
        #if canImport(UIKit)
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            return true
        }
        return false
        #else
        return false
        #endif
    }

    /// Opens the App Store page directly to the Write a Review form.
    @discardableResult
    @MainActor
    public func openAppStoreReviewPage(appStoreId: String) -> Bool {
        Self.openAppStoreReviewPage(appStoreId: appStoreId)
    }

    nonisolated public static func getShareURL(appStoreId: String) -> URL? {
        let cleanId = appStoreId.hasPrefix("id") ? appStoreId : "id\(appStoreId)"
        return URL(string: "https://apps.apple.com/app/\(cleanId)")
    }

    public static func getFeedbackMailURL() -> URL? {
        let appName = Bundle.main.appName
        let appVersion = Bundle.main.releaseVersionNumber
        let appBuild = Bundle.main.buildVersionNumber
        let deviceModel = UIDevice.current.model
        let osVersion = "iOS \(UIDevice.current.systemVersion)"

        let subject = "Feedback: \(appName)"
        let body = """


---
App: \(appName)
Version: \(appVersion) (\(appBuild))
Device: \(deviceModel) (\(osVersion))
"""
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.replacingOccurrences(of: "\n", with: "\r\n")
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        return URL(string: "mailto:\(Constants.feedbackEmail)?subject=\(encodedSubject)&body=\(encodedBody)")
    }

    private static func getTopViewController(base: UIViewController? = nil) -> UIViewController? {
        let baseVC: UIViewController? = base ?? {
            let scenes = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .filter { $0.activationState == .foregroundActive }
            
            for scene in scenes {
                if let keyWindow = scene.windows.first(where: { $0.isKeyWindow && $0.windowLevel == .normal }),
                   let rootVC = keyWindow.rootViewController {
                    return rootVC
                }
            }
            for scene in scenes {
                if let normalWindow = scene.windows.first(where: { $0.windowLevel == .normal }),
                   let rootVC = normalWindow.rootViewController {
                    return rootVC
                }
            }
            return scenes.first?.windows.first?.rootViewController
        }()

        guard let baseVC else { return nil }

        if let presented = baseVC.presentedViewController,
           !presented.isBeingDismissed,
           presented.viewIfLoaded?.window != nil {
            return getTopViewController(base: presented)
        }

        if let nav = baseVC as? UINavigationController {
            return getTopViewController(base: nav.visibleViewController ?? nav.topViewController)
        }
        if let tab = baseVC as? UITabBarController, let selected = tab.selectedViewController {
            return getTopViewController(base: selected)
        }

        if baseVC.viewIfLoaded?.window != nil && !baseVC.isBeingDismissed {
            return baseVC
        }

        return nil
    }

    private static func isHierarchyTransitioning(in scene: UIWindowScene) -> Bool {
        for window in scene.windows where window.windowLevel == .normal {
            if let root = window.rootViewController, hasActiveTransition(in: root) {
                return true
            }
        }
        return false
    }

    private static func hasActiveTransition(in vc: UIViewController) -> Bool {
        if vc.isBeingDismissed || vc.isBeingPresented || vc.transitionCoordinator != nil {
            return true
        }
        if let presented = vc.presentedViewController {
            if hasActiveTransition(in: presented) {
                return true
            }
        }
        return false
    }

    private func markPromptedForCurrentVersion(date: Date = Date()) {
        GraceLogger.success("Marked version '\(self.releaseVersionNumber)' as prompted.", category: .review)
        UserDefaults.standard.set(self.releaseVersionNumber, forKey: SettingKeys.lastVersionPromptedForReviewKey)
        UserDefaults.standard.set(date, forKey: SettingKeys.lastPromptDateKey)
        UserDefaults.standard.set(0, forKey: SettingKeys.milestoneCountKey)
    }

    private func askForReview(retryCount: Int = 0, onPositive: @escaping () -> Void, onNegative: (() -> Void)?) {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            // In headless/test environments without active scenes, mark prompted so test invariants hold.
            markPromptedForCurrentVersion()
            if retryCount < 5 {
                GraceLogger.warning("Active UIWindowScene unavailable. Retrying in 0.3s (attempt \(retryCount + 1)/5)...", category: .review)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.askForReview(retryCount: retryCount + 1, onPositive: onPositive, onNegative: onNegative)
                }
            } else {
                GraceLogger.warning("Could not find active UIWindowScene after 5 retries.", category: .review)
            }
            return
        }

        // Avoid presenting duplicate alert if already visible
        guard alertWindow == nil else {
            GraceLogger.info("Review prompt alert is already presented on alertWindow.", category: .review)
            return
        }

        // If a sheet or modal is currently in transition (e.g. actively dismissing or presenting),
        // delay presentation slightly so transitions settle smoothly before showing the rating prompt.
        if Self.isHierarchyTransitioning(in: windowScene) {
            if retryCount < 10 {
                GraceLogger.info("View hierarchy transitioning (sheet/modal dismissing or presenting). Retrying in 0.25s (attempt \(retryCount + 1)/10)...", category: .review)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                    self?.askForReview(retryCount: retryCount + 1, onPositive: onPositive, onNegative: onNegative)
                }
                return
            }
        }

        markPromptedForCurrentVersion()

        let rawTitle = NSLocalizedString(Constants.StringKeys.reviewPromptTitleFormat, bundle: .module, comment: "")
        let title = String(format: rawTitle, appName)
        let message = NSLocalizedString(Constants.StringKeys.reviewPromptMessage, bundle: .module, comment: "")
        let yesButton = NSLocalizedString(Constants.StringKeys.reviewPromptPositive, bundle: .module, comment: "")
        let noButton = NSLocalizedString(Constants.StringKeys.reviewPromptNegative, bundle: .module, comment: "")

        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )

        let noAction = UIAlertAction(title: noButton, style: .default) { [weak self] _ in
            GraceLogger.info("User selected '\(noButton)'. Redirecting to in-app feedback sheet...", category: .review)
            self?.dismissAlertWindow {
                if let onNegative {
                    onNegative()
                } else {
                    self?.presentFeedbackSheet()
                }
            }
        }
        let yesAction = UIAlertAction(title: yesButton, style: .default) { [weak self] _ in
            GraceLogger.success("User selected '\(yesButton)'. Presenting native StoreKit prompt...", category: .review)
            self?.dismissAlertWindow {
                onPositive()
            }
        }

        alert.addAction(noAction)
        alert.addAction(yesAction)

        // Create a dedicated overlay window above the main app window so that dismissing sheets
        // or other view controller transitions in the app window cannot dismiss or cancel this alert.
        let window = UIWindow(windowScene: windowScene)
        window.windowLevel = .alert + 1
        let rootVC = ReviewAlertContainerViewController()
        rootVC.view.backgroundColor = .clear
        window.rootViewController = rootVC
        window.makeKeyAndVisible()
        self.alertWindow = window

        GraceLogger.info("Presenting pre-filter alert for '\(appName)' on dedicated alert window", category: .review)
        rootVC.present(alert, animated: true, completion: nil)
    }

    public func dismissAlertWindow(completion: (() -> Void)? = nil) {
        if let window = self.alertWindow {
            window.isHidden = true
            self.alertWindow = nil
        }
        completion?()
    }

    /// Presents `FeedbackToGraceView` inside an in-app SwiftUI sheet on top of the active view controller.
    public func presentFeedbackSheet() {
        guard let topVC = Self.getTopViewController() else {
            GraceLogger.warning("Cannot present feedback sheet: topVC unavailable.", category: .feedback)
            return
        }
        
        let title = Bundle.module.localizedString(forKey: Constants.StringKeys.feedbackTitle, value: nil, table: nil)
        
        let feedbackView = NavigationView {
            FeedbackToGraceView()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            topVC.dismiss(animated: true, completion: nil)
                        }
                    }
                }
        }
        
        let hostingController = UIHostingController(rootView: feedbackView)
        hostingController.modalPresentationStyle = .pageSheet
        
        GraceLogger.info("Presenting FeedbackToGraceView in-app sheet on \(type(of: topVC))", category: .feedback)
        topVC.present(hostingController, animated: true, completion: nil)
    }

    private func showNativeReviewPrompt() {
        showNativeReviewPrompt(retryCount: 0)
    }

    private func showNativeReviewPrompt(retryCount: Int) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil &&
              NSClassFromString("XCTestCase") == nil else {
            GraceLogger.info("Unit test detected: skipping StoreKit UI presentation and marking prompted.", category: .review)
            markPromptedForCurrentVersion()
            return
        }

        if ProcessInfo.processInfo.arguments.contains("-UITesting") ||
           ProcessInfo.processInfo.arguments.contains("-MockReviewPrompt") {
            GraceLogger.info("UI test mode detected: presenting MockReviewPromptViewController.", category: .review)
            Self.presentMockReviewPrompt()
            markPromptedForCurrentVersion()
            return
        }

        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
            GraceLogger.warning("Could not find active UIWindowScene to request native review.", category: .review)
            return
        }

        if Self.isHierarchyTransitioning(in: scene) && retryCount < 6 {
            GraceLogger.info("Modal transition in progress while requesting native review. Retrying in 0.3s (attempt \(retryCount + 1)/6)...", category: .review)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.showNativeReviewPrompt(retryCount: retryCount + 1)
            }
            return
        }

        GraceLogger.success("Triggered native StoreKit review prompt in active UIWindowScene.", category: .review)
        if #available(iOS 16.0, *) {
            AppStore.requestReview(in: scene)
        } else {
            SKStoreReviewController.requestReview(in: scene)
        }
        markPromptedForCurrentVersion()
    }

    /// Presents the automated UI testing mock review prompt on the settled root view controller.
    @MainActor
    public static func presentMockReviewPrompt(onDismiss: (() -> Void)? = nil) {
        let promptVC = MockReviewPromptViewController(onDismiss: onDismiss)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let topVC = UIApplication.getTopViewController() {
                topVC.present(promptVC, animated: true)
            }
        }
    }

    public static func actionShareApp(appStoreId: String) {
        guard let appURL = getShareURL(appStoreId: appStoreId) else { return }
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "App"
        let shareText = "Check out this amazing app: \(appName)! Download it here: \(appURL)"
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)

        if let topVC = getTopViewController() {
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = topVC.view
                popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            topVC.present(activityVC, animated: true, completion: nil)
        }
    }
}

private final class ReviewAlertContainerViewController: UIViewController {
    override var preferredStatusBarStyle: UIStatusBarStyle {
        .default
    }
    override var prefersStatusBarHidden: Bool {
        false
    }
}
