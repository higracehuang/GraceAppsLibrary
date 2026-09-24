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
        return count
    }

    private func shouldPrompt() -> Bool {
        let count = recordEngagement()
        return count >= checkpointCount && !hasPromptYet()
    }

    /// Requests a review if conditions are met, presenting pre-filter prompt.
    /// If user taps "Love it!", StoreKit prompt is shown.
    /// If user taps "Not really", `onNegativeFeedback` closure is executed if provided,
    /// or defaults to launching the support feedback email composer.
    public func requestReview(onNegativeFeedback: (() -> Void)? = nil) {
        if shouldPrompt() {
            askForReview(onPositive: showNativeReviewPrompt, onNegative: onNegativeFeedback)
        }
    }

    /// Requests review if conditions are met, returning whether prompt was shown.
    @discardableResult
    public func requestReviewIfNecessary(onNegativeFeedback: (() -> Void)? = nil) -> Bool {
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
            UserDefaults.standard.set(Date(), forKey: SettingKeys.lastEngagementDateKey)
            self.requestReview(onNegativeFeedback: onNegativeFeedback)
        }
    }

    /// Directly presents native StoreKit review prompt without intermediate pre-filter alert.
    public func requestDirectNativeReview() {
        showNativeReviewPrompt()
    }

    public static func debugResetEngagementCounter() {
        UserDefaults.standard.set(0, forKey: SettingKeys.engagementCounterKey)
    }

    public static func appInit() {
        let storedVersion = UserDefaults.standard.string(forKey: SettingKeys.appVersionForStorageKey) ?? ""
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""

        if storedVersion != currentVersion {
            UserDefaults.standard.set(0, forKey: SettingKeys.engagementCounterKey)
            UserDefaults.standard.set(currentVersion, forKey: SettingKeys.appVersionForStorageKey)
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

    private func openDefaultFeedbackMail() {
        guard let url = Self.getFeedbackMailURL() else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
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
        UserDefaults.standard.set(self.releaseVersionNumber, forKey: SettingKeys.lastVersionPromptedForReviewKey)
    }

    private func askForReview(retryCount: Int = 0, onPositive: @escaping () -> Void, onNegative: (() -> Void)?) {
        markPromptedForCurrentVersion()

        guard let topVC = Self.getTopViewController(),
              topVC.viewIfLoaded?.window != nil,
              !topVC.isBeingDismissed else {
            if retryCount < 5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.askForReview(retryCount: retryCount + 1, onPositive: onPositive, onNegative: onNegative)
                }
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
            if let onNegative {
                onNegative()
            } else {
                self?.openDefaultFeedbackMail()
            }
        }
        let yesAction = UIAlertAction(title: yesButton, style: .default) { _ in
            onPositive()
        }

        alert.addAction(noAction)
        alert.addAction(yesAction)

        topVC.present(alert, animated: true, completion: nil)
    }

    private func showNativeReviewPrompt() {
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            if #available(iOS 16.0, *) {
                AppStore.requestReview(in: scene)
            } else {
                SKStoreReviewController.requestReview(in: scene)
            }
            markPromptedForCurrentVersion()
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
