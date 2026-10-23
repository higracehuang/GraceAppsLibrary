//
//  ScreenshotEngine.swift
//  GraceAppsLibrary
//
//  Created by Antigravity on 10/23/26.
//

import Foundation
import SwiftUI
#if canImport(CoreData)
import CoreData
#endif

/// Base coordinator engine for App Store screenshot automation and in-app QA preview.
///
/// Subclass or instantiate inside your app's debug setup:
/// ```swift
/// @MainActor
/// final class AppScreenshotManager: ScreenshotEngine<StandardScreenshotPreset> {
///     static let shared = AppScreenshotManager()
/// }
/// ```
@MainActor
open class ScreenshotEngine<Preset: ScreenshotPresetProvider>: ObservableObject {

    @Published open var activePreset: Preset?
    @Published open var selectedLanguage: ScreenshotLanguage = .auto

    /// Optional closure callback invoked when a preset is applied.
    open var onApply: ((Preset) -> Void)?

    /// Optional closure callback invoked when the screenshot preset is reset.
    open var onReset: (() -> Void)?

    /// Optional closure mapping a preset to a root tab index. Overrides preset.targetTabIndex if non-nil.
    open var tabIndexForPreset: ((Preset) -> Int?)?

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

    /// Automatically switches the selected tab if the active preset defines a `targetTabIndex`,
    /// and invokes `apply(preset:)` if `autoApply` is true.
    open func handleAppLaunch(selectedTab: Binding<Int>? = nil, autoApply: Bool = true) {
        guard let preset = activePreset else { return }
        let targetTab = tabIndexForPreset?(preset) ?? preset.targetTabIndex
        if let targetTab = targetTab {
            selectedTab?.wrappedValue = targetTab
        }
        if autoApply {
            apply(preset: preset)
        }
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

    /// Applies a preset. Subclasses or `onApply` closures can populate app-specific mock data.
    open func apply(preset: Preset) {
        self.activePreset = preset
        onApply?(preset)
    }

    /// Resets screenshot state to default normal launch.
    open func reset() {
        self.activePreset = nil
        onReset?()
    }
}

#if canImport(CoreData)
extension ScreenshotEngine {
    /// Verifies that the managed object context is backed by an in-memory or /dev/null store.
    /// Prevents screenshot demo data seeders from mutating persistent user production SQLite databases.
    public nonisolated static func isInMemoryStore(context: NSManagedObjectContext) -> Bool {
        guard let stores = context.persistentStoreCoordinator?.persistentStores, !stores.isEmpty else {
            return false
        }
        return stores.allSatisfy { $0.url?.path == "/dev/null" || $0.type == NSInMemoryStoreType }
    }
}
#endif
