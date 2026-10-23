//
//  ScreenshotEngine.swift
//  GraceAppsLibrary
//
//  Created by Antigravity on 10/23/26.
//

import Foundation
import SwiftUI

/// Base coordinator engine for App Store screenshot automation and in-app QA preview.
///
/// Subclass or instantiate inside your app's debug setup:
/// ```swift
/// @MainActor
/// final class AppScreenshotManager: ScreenshotEngine<AppScreenshotPreset> {
///     static let shared = AppScreenshotManager()
/// }
/// ```
@MainActor
open class ScreenshotEngine<Preset: ScreenshotPresetProvider>: ObservableObject {

    @Published open var activePreset: Preset?
    @Published open var selectedLanguage: ScreenshotLanguage = .auto

    public init(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        if let launchLang = ScreenshotLanguage.fromLaunchEnvironment(arguments: arguments, environment: environment) {
            self.selectedLanguage = launchLang
        }
        if let launchPreset = Self.parseLaunchPreset(arguments: arguments, environment: environment) {
            self.activePreset = launchPreset
        }
    }

    /// Whether the app is currently running under an automated screenshot capture run.
    open var isScreenshotCaptureActive: Bool {
        activePreset != nil
    }

    /// The effective language for demo data and copy.
    open var effectiveLanguage: ScreenshotLanguage {
        selectedLanguage.resolved
    }

    /// Parses the preset flag (`-SCREENSHOT_PRESET <token>` or environment variable).
    public static func parseLaunchPreset(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Preset? {
        var rawToken: String?
        if let idx = arguments.firstIndex(where: { $0 == "-SCREENSHOT_PRESET" || $0 == "-screenshotPreset" }),
           idx + 1 < arguments.count {
            rawToken = arguments[idx + 1]
        } else if let envVal = environment["SCREENSHOT_PRESET"] {
            rawToken = envVal
        }

        guard let token = rawToken else { return nil }
        return Preset.from(token: token)
    }

    /// Prepares standard marketing state (forces Pro entitlement, removes banner ads).
    open func configureMarketingEntitlement(entitlementOverride: Binding<DebugEntitlementOverride>?) {
        entitlementOverride?.wrappedValue = .forcePro
    }

    /// Applies a preset. Subclasses can override to populate app-specific mock data.
    open func apply(preset: Preset) {
        self.activePreset = preset
    }

    /// Resets screenshot state to default normal launch.
    open func reset() {
        self.activePreset = nil
    }
}
