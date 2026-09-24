//
//  ReviewPromptManager.swift
//  GraceAppsLibrary
//

import Foundation
import StoreKit
import UIKit
import SwiftUI

@MainActor
public class ReviewPromptManager {

    public static let shared = ReviewPromptManager()

    private var checkpointCount: Int

    public init(checkpointCount: Int = 5) {
        self.checkpointCount = checkpointCount
    }
    
    private struct SettingKeys {
        static let engagementCounterKey = "GraceApps_Review_EngagementCounter"
        static let lastVersionPromptedForReviewKey = "GraceApps_Review_LastVersionPromptedForReview"
        static let appVersionForStorageKey = "GraceApps_Review_AppVersionForStorage"
        static let lastEngagementDateKey = "GraceApps_Review_LastEngagementDate"
    }

    private var appName: String {
        Bundle.main.appName
    }

    private var releaseVersionNumber: String {
        Bundle.main.releaseVersionNumber
    }

    private func recordEngagement() -> Int {
        var count = UserDefaults.standard.integer(forKey: SettingKeys.engagementCounterKey)
        count += 1
        UserDefaults.standard.set(count, forKey: SettingKeys.engagementCounterKey)
        GraceLogger.info("Recorded engagement count: \(count) / checkpoint: \(checkpointCount)", category: .review)
        return count
    }

    private func shouldPrompt() -> Bool {
        let count = recordEngagement()
        let alreadyPrompted = hasPromptYet()
        let result = count >= checkpointCount && !alreadyPrompted
        GraceLogger.info("Evaluate shouldPrompt: count=\(count), checkpoint=\(checkpointCount), hasPromptedYet=\(alreadyPrompted) -> \(result ? "SHOULD PROMPT" : "SKIP")", category: .review)
        return result
    }

    /// Requests a review if conditions are met (or forced), presenting pre-filter prompt.
    /// If user taps "Love it!", StoreKit prompt is shown.
    /// If user taps "Not really", `onNegativeFeedback` closure is executed if provided,
    /// or defaults to launching the support feedback email composer.
    public func requestReview(onNegativeFeedback: (() -> Void)? = nil) {
        GraceLogger.info("requestReview() invoked", category: .review)
        if shouldPrompt() {
            askForReview(onPositive: showNativeReviewPrompt, onNegative: onNegativeFeedback)
        }
    }

    /// Requests review if conditions are met, returning whether prompt was shown.
    @discardableResult
    public func requestReviewIfNecessary(onNegativeFeedback: (() -> Void)? = nil) -> Bool {
        GraceLogger.info("requestReviewIfNecessary() invoked", category: .review)
        if shouldPrompt() {
            askForReview(onPositive: showNativeReviewPrompt, onNegative: onNegativeFeedback)
            return true
        }
        return false
    }

    /// Triggers review request daily throttled.
    public func requestReviewDaily(onNegativeFeedback: (() -> Void)? = nil) {
        let lastDate = UserDefaults.standard.object(forKey: SettingKeys.lastEngagementDateKey) as? Date
        if lastDate == nil || !Calendar.current.isDateInToday(lastDate!) {
            GraceLogger.info("Daily review check passed. Requesting review...", category: .review)
            UserDefaults.standard.set(Date(), forKey: SettingKeys.lastEngagementDateKey)
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

    public static func debugResetEngagementCounter() {
        UserDefaults.standard.set(0, forKey: SettingKeys.engagementCounterKey)
        UserDefaults.standard.removeObject(forKey: SettingKeys.lastVersionPromptedForReviewKey)
        UserDefaults.standard.removeObject(forKey: SettingKeys.lastEngagementDateKey)
        GraceLogger.info("Reset engagement counter to 0 and cleared prompted version status.", category: .debug)
    }

    public static func appInit() {
        let storedVersion = UserDefaults.standard.string(forKey: SettingKeys.appVersionForStorageKey) ?? ""
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""

        if storedVersion != currentVersion {
            GraceLogger.info("App version changed ('\(storedVersion)' -> '\(currentVersion)'). Resetting engagement counter.", category: .app)
            UserDefaults.standard.set(0, forKey: SettingKeys.engagementCounterKey)
            UserDefaults.standard.set(currentVersion, forKey: SettingKeys.appVersionForStorageKey)
        } else {
            GraceLogger.info("App initialized for version '\(currentVersion)'.", category: .app)
        }
    }

    public func hasPromptYet() -> Bool {
        let lastVersionPrompted = UserDefaults.standard.string(forKey: SettingKeys.lastVersionPromptedForReviewKey) ?? ""
        let currentVersion = releaseVersionNumber
        return lastVersionPrompted == currentVersion
    }

    public static func getReviewURL(appStoreId: String) -> URL? {
        let cleanId = appStoreId.hasPrefix("id") ? appStoreId : "id\(appStoreId)"
        return URL(string: "https://apps.apple.com/app/\(cleanId)?action=write-review")
    }

    public static func getShareURL(appStoreId: String) -> URL? {
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
                if let keyWindow = scene.windows.first(where: { $0.isKeyWindow }),
                   let rootVC = keyWindow.rootViewController {
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

    private func markPromptedForCurrentVersion() {
        GraceLogger.success("Marked version '\(self.releaseVersionNumber)' as prompted.", category: .review)
        UserDefaults.standard.set(self.releaseVersionNumber, forKey: SettingKeys.lastVersionPromptedForReviewKey)
    }

    private func askForReview(retryCount: Int = 0, onPositive: @escaping () -> Void, onNegative: (() -> Void)?) {
        markPromptedForCurrentVersion()

        guard let topVC = Self.getTopViewController(),
              topVC.viewIfLoaded?.window != nil,
              !topVC.isBeingDismissed else {
            if retryCount < 5 {
                GraceLogger.warning("Top view controller unavailable/dismissing. Retrying presentation in 0.3s (attempt \(retryCount + 1)/5)...", category: .review)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.askForReview(retryCount: retryCount + 1, onPositive: onPositive, onNegative: onNegative)
                }
            } else {
                GraceLogger.warning("Could not find stable top view controller after 5 retries.", category: .review)
            }
            return
        }

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
            if let onNegative {
                onNegative()
            } else {
                self?.presentFeedbackSheet()
            }
        }
        let yesAction = UIAlertAction(title: yesButton, style: .default) { _ in
            GraceLogger.success("User selected '\(yesButton)'. Presenting native StoreKit prompt...", category: .review)
            onPositive()
        }

        alert.addAction(noAction)
        alert.addAction(yesAction)

        GraceLogger.info("Presenting pre-filter alert for '\(appName)' on \(type(of: topVC))", category: .review)
        topVC.present(alert, animated: true, completion: nil)
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
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            GraceLogger.success("Triggered native StoreKit review prompt in active UIWindowScene.", category: .review)
            if #available(iOS 16.0, *) {
                AppStore.requestReview(in: scene)
            } else {
                SKStoreReviewController.requestReview(in: scene)
            }
            markPromptedForCurrentVersion()
        } else {
            GraceLogger.warning("Could not find active UIWindowScene to request native review.", category: .review)
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
