//
//  ScreenshotEngine.swift
//  GraceAppsLibrary
//
//  Created by Antigravity on 10/23/26.
//

import Foundation
import SwiftUI
import GraceAppsLibrary
#if canImport(CoreData)
import CoreData
#endif
#if canImport(SwiftData)
import SwiftData
#endif

/// Result returned when applying a screenshot preset via `ScreenshotEngine`.
public enum ScreenshotApplyResult: Equatable, Sendable {
    case applied(presetId: String, language: ScreenshotLanguage)
    case blockedUnsafeStore(String)
    case noPreset
}

/// Validates that the backing persistence store is safe for destructive/demo screenshot seeding.
public struct ScreenshotStoreSafety {
    private let validator: () -> String?

    private init(validator: @escaping () -> String?) {
        self.validator = validator
    }

    /// Returns `nil` when safe to seed, or a human-readable failure reason when blocked.
    public func validate() -> String? {
        validator()
    }

    #if canImport(CoreData)
    /// Verifies that the CoreData context uses an in-memory or `/dev/null` store unless `allowMockOverride` is enabled.
    public static func coreData(
        _ context: NSManagedObjectContext,
        allowMockOverride: Bool = false
    ) -> ScreenshotStoreSafety {
        ScreenshotStoreSafety {
            if allowMockOverride || isInMemoryStore(context: context) {
                return nil
            }
            return "Blocked screenshot seeding: CoreData context is not backed by an in-memory or /dev/null store."
        }
    }

    /// Verifies that the managed object context is backed by an in-memory or `/dev/null` store.
    /// Fails closed (`false`) if no persistent stores are attached.
    public nonisolated static func isInMemoryStore(context: NSManagedObjectContext) -> Bool {
        guard let stores = context.persistentStoreCoordinator?.persistentStores, !stores.isEmpty else {
            return false
        }
        return stores.allSatisfy { $0.url?.path == "/dev/null" || $0.type == NSInMemoryStoreType }
    }
    #endif

    #if canImport(SwiftData)
    /// Verifies that the SwiftData context is configured with in-memory-only storage unless `allowMockOverride` is enabled.
    @available(iOS 17, watchOS 10, *)
    public static func swiftData(
        _ context: ModelContext,
        allowMockOverride: Bool = false
    ) -> ScreenshotStoreSafety {
        ScreenshotStoreSafety {
            if allowMockOverride || isInMemoryStore(context: context) {
                return nil
            }
            return "Blocked screenshot seeding: SwiftData context is not stored in-memory only."
        }
    }

    /// Verifies that all SwiftData container configurations are stored in-memory only.
    /// Fails closed (`false`) if the container has no configurations.
    @available(iOS 17, watchOS 10, *)
    public nonisolated static func isInMemoryStore(context: ModelContext) -> Bool {
        let configurations = context.container.configurations
        guard !configurations.isEmpty else {
            return false
        }
        return configurations.allSatisfy { $0.isStoredInMemoryOnly }
    }
    #endif

    /// Custom store safety predicate. Returning `false` blocks seeding with `reason`.
    public static func custom(
        _ reason: String = "Store safety check failed",
        check: @escaping () -> Bool
    ) -> ScreenshotStoreSafety {
        ScreenshotStoreSafety {
            check() ? nil : reason
        }
    }
}

/// Scoped, reversible environment overrides applied during screenshot preset activation.
public struct ScreenshotEnvironmentConfig {
    public var userDefaultsSuite: UserDefaults
    public var defaultsOverrides: [String: Any]
    public var suppressReleaseNotes: Bool

    public init(
        userDefaultsSuite: UserDefaults = .standard,
        defaultsOverrides: [String: Any] = [:],
        suppressReleaseNotes: Bool = true
    ) {
        self.userDefaultsSuite = userDefaultsSuite
        self.defaultsOverrides = defaultsOverrides
        self.suppressReleaseNotes = suppressReleaseNotes
    }
}

/// Template contract for app-specific `ScreenshotDemoManager` coordinators.
///
/// `ScreenshotEngine` conforms to this protocol and handles launch parsing,
/// store-safety gating, one-shot launch protection, environment snapshot/restore,
/// and SwiftUI tab coordination. App coordinators subclass `ScreenshotEngine`
/// and override only the hooks they need.
@MainActor
public protocol ScreenshotDemoCoordinating: ObservableObject {
    associatedtype Preset: ScreenshotPresetProvider

    var activePreset: Preset? { get set }
    var selectedLanguage: ScreenshotLanguage { get set }
    var isScreenshotCaptureActive: Bool { get }
    var effectiveLanguage: ScreenshotLanguage { get }
    var navigationTriggerId: UUID { get }

    /// Scoped `UserDefaults` overrides and release-notes suppression applied for screenshots.
    func makeEnvironmentConfig() -> ScreenshotEnvironmentConfig

    /// Store safety validator checked before any demo seeding runs.
    func makeStoreSafety() -> ScreenshotStoreSafety?

    /// Optional entitlement override binding (e.g., `UniversalPurchaseCoordinator.shared.debugOverride`).
    func makeEntitlementOverrideBinding() -> Binding<DebugEntitlementOverride>?

    /// Seeds app-specific mock data for the validated preset and resolved language.
    func seedMockData(for preset: Preset, language: ScreenshotLanguage)

    /// Updates app-specific navigation / sheet / simulation state for the preset.
    func coordinateNavigation(for preset: Preset)

    /// Resets app-specific state when `reset()` is called.
    func resetAppState()
}

/// Protocol for screenshot coordinators or demo seeders that provide explicit store-safe
/// clear and seed operations (for automated presets, QA debug buttons, and unit tests).
@MainActor
public protocol ScreenshotMockDataSeeding {
    associatedtype StoreContext

    /// Removes existing records from `context`.
    func clearDemoData(in context: StoreContext)

    /// Seeds deterministic demo records into `context` for `language`.
    func seedDemoData(in context: StoreContext, language: ScreenshotLanguage)
}

public extension ScreenshotMockDataSeeding {
    /// Clears and seeds demo data only if `safety.validate()` passes.
    /// Returns `nil` when seeding ran, or the block reason string when blocked.
    @discardableResult
    func safelyClearAndSeedDemoData(
        in context: StoreContext,
        language: ScreenshotLanguage,
        safety: ScreenshotStoreSafety
    ) -> String? {
        if let reason = safety.validate() {
            return reason
        }
        clearDemoData(in: context)
        seedDemoData(in: context, language: language)
        return nil
    }
}

/// Base coordinator engine for App Store screenshot automation and in-app QA preview.
///
/// Subclass `ScreenshotEngine` and override `ScreenshotDemoCoordinating` template methods,
/// or attach closures (`onApply`, `onReset`, `storeSafetyProvider`) for lightweight setups:
/// ```swift
/// @MainActor
/// final class ScreenshotDemoManager: ScreenshotEngine<AppScreenshotPreset> {
///     static let shared = ScreenshotDemoManager()
///
///     override func makeStoreSafety() -> ScreenshotStoreSafety? {
///         .coreData(PersistenceController.shared.container.viewContext)
///     }
///
///     override func seedMockData(for preset: AppScreenshotPreset, language: ScreenshotLanguage) {
///         ...
///     }
/// }
/// ```
@MainActor
open class ScreenshotEngine<Preset: ScreenshotPresetProvider>: ScreenshotDemoCoordinating {

    @Published open var activePreset: Preset?
    @Published open var selectedLanguage: ScreenshotLanguage = .auto
    /// Bumped on every successful apply / reset so `screenshotTabCoordination` re-syncs tab selection.
    @Published open var navigationTriggerId = UUID()

    /// Optional closure callback invoked when a preset is applied.
    open var onApply: ((Preset) -> Void)?

    /// Optional closure callback invoked when the screenshot preset is reset.
    open var onReset: (() -> Void)?

    /// Optional closure mapping a preset to a root tab index. Overrides preset.targetTabIndex if non-nil.
    open var tabIndexForPreset: ((Preset) -> Int?)?

    /// Optional dynamic store safety provider evaluated when `apply(preset:storeSafety:)` is called with `storeSafety == nil`.
    open var storeSafetyProvider: (() -> ScreenshotStoreSafety?)?

    /// Optional static fallback store safety check evaluated if `storeSafety` and `storeSafetyProvider` are `nil`.
    open var defaultStoreSafety: ScreenshotStoreSafety?

    /// Scoped `UserDefaults` overrides and release-notes suppression settings applied on `apply` and restored on `reset()`.
    open var environmentConfig = ScreenshotEnvironmentConfig()

    /// Tracks whether `handleAppLaunch` has already applied the launch preset in this session.
    public private(set) var hasAppliedLaunchPreset: Bool = false

    /// When taking screenshots, automatically assumes forced Pro status for marketing captures.
    open var assumeForcedPro: Bool = true

    #if DEBUG
    private enum DefaultsSnapshotValue {
        case present(Any)
        case absent
    }

    private struct EnvironmentSnapshot {
        var suiteSnapshots: [ObjectIdentifier: (suite: UserDefaults, values: [String: DefaultsSnapshotValue])] = [:]
        var releaseNotesSnapshot: (evaluated: Bool, shown: Bool)?
    }

    private let launchArguments: [String]
    private let launchEnvironment: [String: String]
    private var isLaunchCaptureFlagged: Bool = false
    private var environmentSnapshot: EnvironmentSnapshot?
    #endif

    public init(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        #if DEBUG
        self.launchArguments = arguments
        self.launchEnvironment = environment
        self.isLaunchCaptureFlagged = Self.isScreenshotCaptureActive(arguments: arguments, environment: environment)
        if let launchLang = ScreenshotLanguage.fromLaunchEnvironment(arguments: arguments, environment: environment) {
            self.selectedLanguage = launchLang
        }
        if let launchPreset = Self.parseLaunchPreset(arguments: arguments, environment: environment) {
            self.activePreset = launchPreset
        }
        #endif
    }

    /// Whether the app is currently running under an automated screenshot capture run.
    open var isScreenshotCaptureActive: Bool {
        #if DEBUG
        return activePreset != nil || isLaunchCaptureFlagged
        #else
        return false
        #endif
    }

    /// Whether screenshot capture is currently active in the process environment.
    public static func isScreenshotCaptureActive(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        DebugEntitlementOverride.isScreenshotCaptureActive(arguments: arguments, environment: environment)
    }

    /// The effective language for demo data and copy.
    open var effectiveLanguage: ScreenshotLanguage {
        selectedLanguage.resolved
    }

    /// Supported screenshot languages detected for the current application bundle.
    open var supportedLanguages: [ScreenshotLanguage] {
        ScreenshotLanguage.supportedLanguages(in: .main)
    }

    // MARK: - Template Hooks (`ScreenshotDemoCoordinating`)

    /// Returns the scoped environment config to snapshot and apply. Defaults to `environmentConfig`.
    open func makeEnvironmentConfig() -> ScreenshotEnvironmentConfig {
        environmentConfig
    }

    /// Returns the store safety validator evaluated when `apply` / `handleAppLaunch` is called without an explicit `storeSafety`.
    /// Defaults to `storeSafetyProvider?() ?? defaultStoreSafety`.
    open func makeStoreSafety() -> ScreenshotStoreSafety? {
        storeSafetyProvider?() ?? defaultStoreSafety
    }

    /// Returns the entitlement override binding configured during screenshot launches/applies. Defaults to `nil`.
    open func makeEntitlementOverrideBinding() -> Binding<DebugEntitlementOverride>? {
        nil
    }

    /// Override in subclasses to populate CoreData/SwiftData mock records for `preset` and `language`.
    open func seedMockData(for preset: Preset, language: ScreenshotLanguage) {}

    /// Override in subclasses to update app-specific navigation / sheet / simulation flags for `preset`.
    open func coordinateNavigation(for preset: Preset) {}

    /// Override in subclasses to clear app-specific state during `reset()`.
    open func resetAppState() {}

    /// Automatically switches the selected tab if the active preset defines a `targetTabIndex`,
    /// configures Pro entitlement if `assumeForcedPro` is enabled (respecting `-FORCE_FREE` / `.forceFree`),
    /// enforces one-shot launch protection (`hasAppliedLaunchPreset`), and invokes `apply(preset:storeSafety:)` if `autoApply` is true.
    @discardableResult
    open func handleAppLaunch(
        selectedTab: Binding<Int>? = nil,
        entitlementOverride: Binding<DebugEntitlementOverride>? = nil,
        storeSafety: ScreenshotStoreSafety? = nil,
        autoApply: Bool = true
    ) -> ScreenshotApplyResult {
        #if DEBUG
        guard !hasAppliedLaunchPreset else { return .noPreset }
        let effectiveEntitlement = entitlementOverride ?? makeEntitlementOverrideBinding()
        guard let preset = activePreset else {
            if assumeForcedPro && isScreenshotCaptureActive {
                configureMarketingEntitlement(entitlementOverride: effectiveEntitlement)
            }
            return .noPreset
        }

        if autoApply {
            let effectiveSafety = storeSafety ?? makeStoreSafety()
            if let reason = effectiveSafety?.validate() {
                return .blockedUnsafeStore(reason)
            }
            hasAppliedLaunchPreset = true
            if assumeForcedPro && isScreenshotCaptureActive {
                configureMarketingEntitlement(entitlementOverride: effectiveEntitlement)
            }
            if let targetTab = tabIndexForPreset?(preset) ?? preset.targetTabIndex {
                selectedTab?.wrappedValue = targetTab
            }
            return applyValidated(preset: preset, entitlementOverride: effectiveEntitlement)
        } else {
            if assumeForcedPro && isScreenshotCaptureActive {
                configureMarketingEntitlement(entitlementOverride: effectiveEntitlement)
            }
            if let targetTab = tabIndexForPreset?(preset) ?? preset.targetTabIndex {
                selectedTab?.wrappedValue = targetTab
            }
            navigationTriggerId = UUID()
            return .noPreset
        }
        #else
        return .noPreset
        #endif
    }

    /// Parses the preset flag (`-SCREENSHOT_PRESET <token>` or environment variable).
    public static func parseLaunchPreset(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Preset? {
        #if DEBUG
        var rawToken: String?
        if let idx = arguments.firstIndex(where: { $0 == "-SCREENSHOT_PRESET" || $0 == "-screenshotPreset" }),
           idx + 1 < arguments.count {
            rawToken = arguments[idx + 1]
        } else if let envVal = environment["SCREENSHOT_PRESET"] {
            rawToken = envVal
        }

        guard let token = rawToken else { return nil }
        return Preset.from(token: token)
        #else
        return nil
        #endif
    }

    /// Prepares standard marketing state (forces Pro entitlement unless `.forceFree` or `-FORCE_FREE` is active).
    open func configureMarketingEntitlement(entitlementOverride: Binding<DebugEntitlementOverride>?) {
        #if DEBUG
        guard let entitlementOverride = entitlementOverride else { return }
        if entitlementOverride.wrappedValue == .forceFree ||
            Self.hasForceFreeFlag(arguments: launchArguments, environment: launchEnvironment) ||
            Self.hasForceFreeFlag(arguments: ProcessInfo.processInfo.arguments, environment: ProcessInfo.processInfo.environment) {
            return
        }
        entitlementOverride.wrappedValue = .forcePro
        #endif
    }

    /// Applies a preset after validating store safety, applying scoped environment overrides,
    /// seeding mock data, coordinating navigation, and invoking `onApply`.
    @discardableResult
    open func apply(
        preset: Preset,
        storeSafety: ScreenshotStoreSafety? = nil
    ) -> ScreenshotApplyResult {
        #if DEBUG
        let effectiveSafety = storeSafety ?? makeStoreSafety()
        if let reason = effectiveSafety?.validate() {
            return .blockedUnsafeStore(reason)
        }
        return applyValidated(preset: preset, entitlementOverride: makeEntitlementOverrideBinding())
        #else
        return .noPreset
        #endif
    }

    /// Resets screenshot state to default normal launch, restores snapshotted environment state,
    /// calls `resetAppState()`, and invokes `onReset`.
    open func reset() {
        #if DEBUG
        hasAppliedLaunchPreset = false
        activePreset = nil
        isLaunchCaptureFlagged = false
        restoreEnvironmentSnapshot()
        resetAppState()
        navigationTriggerId = UUID()
        onReset?()
        #endif
    }

    #if DEBUG
    private func applyValidated(
        preset: Preset,
        entitlementOverride: Binding<DebugEntitlementOverride>?
    ) -> ScreenshotApplyResult {
        let config = makeEnvironmentConfig()
        captureEnvironmentSnapshotIfNeeded(using: config)
        applyEnvironmentOverrides(using: config)

        self.activePreset = preset
        if assumeForcedPro {
            configureMarketingEntitlement(entitlementOverride: entitlementOverride)
        }
        let resolvedLanguage = effectiveLanguage
        seedMockData(for: preset, language: resolvedLanguage)
        coordinateNavigation(for: preset)
        onApply?(preset)
        navigationTriggerId = UUID()
        return .applied(presetId: preset.id, language: resolvedLanguage)
    }

    private static func hasForceFreeFlag(
        arguments: [String],
        environment: [String: String]
    ) -> Bool {
        let freeFlags = ["-FORCE_FREE", "-ForceFree", "-forceFree", "-UI_TEST_FREE_TIER"]
        if arguments.contains(where: { freeFlags.contains($0) }) {
            return true
        }
        if let envValue = environment["FORCE_FREE"], !envValue.isEmpty {
            let lowered = envValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return lowered != "0" && lowered != "false" && lowered != "no"
        }
        return false
    }

    private func captureEnvironmentSnapshotIfNeeded(using config: ScreenshotEnvironmentConfig) {
        var snapshot = environmentSnapshot ?? EnvironmentSnapshot()

        let suite = config.userDefaultsSuite
        let suiteId = ObjectIdentifier(suite)
        var suiteEntry = snapshot.suiteSnapshots[suiteId] ?? (suite: suite, values: [:])

        for key in config.defaultsOverrides.keys where suiteEntry.values[key] == nil {
            if let existingValue = suite.object(forKey: key) {
                suiteEntry.values[key] = .present(existingValue)
            } else {
                suiteEntry.values[key] = .absent
            }
        }
        snapshot.suiteSnapshots[suiteId] = suiteEntry

        if config.suppressReleaseNotes && snapshot.releaseNotesSnapshot == nil {
            snapshot.releaseNotesSnapshot = (
                evaluated: ReleaseNotesManager.shared.hasEvaluatedLaunchReleaseNotes,
                shown: ReleaseNotesManager.hasShownReleaseNotesThisSession
            )
        }

        environmentSnapshot = snapshot
    }

    private func applyEnvironmentOverrides(using config: ScreenshotEnvironmentConfig) {
        let suite = config.userDefaultsSuite
        for (key, value) in config.defaultsOverrides {
            if value is NSNull {
                suite.removeObject(forKey: key)
            } else if let url = value as? URL {
                suite.set(url, forKey: key)
            } else {
                suite.set(value, forKey: key)
            }
        }

        if config.suppressReleaseNotes {
            ReleaseNotesManager.shared.setSessionSuppressionForTesting(evaluated: true, shown: true)
        }
    }

    private func restoreEnvironmentSnapshot() {
        guard let snapshot = environmentSnapshot else { return }

        for (_, entry) in snapshot.suiteSnapshots {
            for (key, value) in entry.values {
                switch value {
                case .present(let original):
                    entry.suite.set(original, forKey: key)
                case .absent:
                    entry.suite.removeObject(forKey: key)
                }
            }
        }

        if let rnSnapshot = snapshot.releaseNotesSnapshot {
            ReleaseNotesManager.shared.setSessionSuppressionForTesting(
                evaluated: rnSnapshot.evaluated,
                shown: rnSnapshot.shown
            )
        }

        environmentSnapshot = nil
    }
    #endif
}

#if canImport(CoreData)
extension ScreenshotEngine {
    /// Verifies that the managed object context is backed by an in-memory or /dev/null store.
    /// Prevents screenshot demo data seeders from mutating persistent user production SQLite databases.
    public nonisolated static func isInMemoryStore(context: NSManagedObjectContext) -> Bool {
        ScreenshotStoreSafety.isInMemoryStore(context: context)
    }
}
#endif

#if canImport(SwiftData)
@available(iOS 17, watchOS 10, *)
extension ScreenshotEngine {
    /// Verifies that the SwiftData context is configured with in-memory-only storage.
    /// Prevents screenshot demo data seeders from mutating persistent user production stores.
    public nonisolated static func isInMemoryStore(context: ModelContext) -> Bool {
        ScreenshotStoreSafety.isInMemoryStore(context: context)
    }
}
#endif
