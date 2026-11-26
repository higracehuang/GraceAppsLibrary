//
//  ScreenshotAutomationTests.swift
//  GraceAppsLibraryTests
//
//  Created by Antigravity on 10/23/26.
//

import XCTest
import SwiftUI
#if canImport(CoreData)
import CoreData
#endif
#if canImport(SwiftData)
import SwiftData
#endif
#if canImport(UIKit)
import UIKit
#endif
@testable import GraceAppsLibrary
@testable import GraceAppsLibraryDebug

private enum MockPreset: String, ScreenshotPresetProvider {
    case first = "1"
    case second = "2"
    case celebration = "4b"

    var slotLabel: String {
        switch self {
        case .first: return "Slot #1 • First Feature"
        case .second: return "Slot #2 • Second Feature"
        case .celebration: return "Slot #4B • Celebration"
        }
    }

    var title: String {
        switch self {
        case .first: return "Feature One"
        case .second: return "Feature Two"
        case .celebration: return "Streak Celebration"
        }
    }

    var suggestedFilename: String {
        switch self {
        case .first: return "01 - Feature One"
        case .second: return "02 - Feature Two"
        case .celebration: return "04B - Streak Celebration"
        }
    }

    var systemImage: String {
        switch self {
        case .first: return "star"
        case .second: return "heart"
        case .celebration: return "trophy"
        }
    }

    var targetTabIndex: Int? {
        switch self {
        case .first: return 0
        case .second: return 1
        case .celebration: return 2
        }
    }
}

private enum OverlapTokenPreset: String, ScreenshotPresetProvider {
    case alpha = "a"
    case beta = "beta"
    case gamma = "g"

    var slotLabel: String { rawValue }

    var title: String {
        switch self {
        case .alpha: return "Beta Overview"
        case .beta: return "Alpha Details"
        case .gamma: return "Summary Beta"
        }
    }

    var suggestedFilename: String {
        switch self {
        case .alpha: return "01 - Beta Alias"
        case .beta: return "02 - Delta"
        case .gamma: return "03 - Gamma Item"
        }
    }

    var systemImage: String { "star" }

    var aliases: [String] {
        switch self {
        case .alpha: return ["gamma", "primary"]
        case .beta: return ["alpha_alias"]
        case .gamma: return ["beta_alias"]
        }
    }
}

private enum CustomIdPreset: String, ScreenshotPresetProvider {
    case first = "raw_first"
    case second = "raw_second"

    var id: String {
        switch self {
        case .first: return "custom_id_alpha"
        case .second: return "custom_id_beta"
        }
    }

    var slotLabel: String { rawValue }
    var title: String { rawValue }
    var suggestedFilename: String { rawValue }
    var systemImage: String { "circle" }
}

private enum TestTab: Hashable {
    case home
    case trends
    case settings
}

#if canImport(SwiftData)
@available(iOS 17, watchOS 10, *)
@Model
fileprivate final class ScreenshotSafetyTestRecord {
    var label: String

    init(label: String = "seed") {
        self.label = label
    }
}
#endif

#if canImport(UIKit)
@MainActor
private struct TabCoordIntTestView: View {
    @ObservedObject var engine: ScreenshotEngine<MockPreset>
    @Binding var selectedTab: Int
    let tabForPreset: (@MainActor (MockPreset) -> Int?)?

    var body: some View {
        Text("Tab \(selectedTab)")
            .screenshotTabCoordination(
                engine: engine,
                selectedTab: $selectedTab,
                tabForPreset: tabForPreset
            )
    }
}

@MainActor
private struct TabCoordIntDefaultTestView: View {
    @ObservedObject var engine: ScreenshotEngine<MockPreset>
    @Binding var selectedTab: Int

    var body: some View {
        Text("Tab \(selectedTab)")
            .screenshotTabCoordination(
                engine: engine,
                selectedTab: $selectedTab
            )
    }
}

@MainActor
private struct TabCoordHashableTestView: View {
    @ObservedObject var engine: ScreenshotEngine<MockPreset>
    @Binding var selectedTab: TestTab
    let tabForPreset: @MainActor (MockPreset) -> TestTab?

    var body: some View {
        Text("Tab \(String(describing: selectedTab))")
            .screenshotTabCoordination(
                engine: engine,
                selectedTab: $selectedTab,
                tabForPreset: tabForPreset
            )
    }
}
#endif

final class ScreenshotAutomationTests: XCTestCase {

    // MARK: - Baseline Tests (Preserved)

    func testLanguageTokenMatching() {
        XCTAssertEqual(ScreenshotLanguage.from(token: "en"), .english)
        XCTAssertEqual(ScreenshotLanguage.from(token: "English"), .english)
        XCTAssertEqual(ScreenshotLanguage.from(token: "zh-Hans"), .simplifiedChinese)
        XCTAssertEqual(ScreenshotLanguage.from(token: "chinese"), .simplifiedChinese)
        XCTAssertEqual(ScreenshotLanguage.from(token: "de"), .german)
        XCTAssertEqual(ScreenshotLanguage.from(token: "german"), .german)
        XCTAssertEqual(ScreenshotLanguage.from(token: "es"), .spanish)
        XCTAssertEqual(ScreenshotLanguage.from(token: "spanish"), .spanish)
        XCTAssertEqual(ScreenshotLanguage.from(token: "ja"), .japanese)
        XCTAssertEqual(ScreenshotLanguage.from(token: "japanese"), .japanese)
        XCTAssertEqual(ScreenshotLanguage.from(token: "fr"), .french)
        XCTAssertEqual(ScreenshotLanguage.from(token: "french"), .french)
        XCTAssertEqual(ScreenshotLanguage.from(token: "unknown"), nil)
    }

    func testLanguageAppleCodesAndLocales() {
        XCTAssertEqual(ScreenshotLanguage.english.appleLanguageCode, "en")
        XCTAssertEqual(ScreenshotLanguage.english.appleLocaleIdentifier, "en_US")

        XCTAssertEqual(ScreenshotLanguage.simplifiedChinese.appleLanguageCode, "zh-Hans")
        XCTAssertEqual(ScreenshotLanguage.simplifiedChinese.appleLocaleIdentifier, "zh_CN")

        XCTAssertEqual(ScreenshotLanguage.spanish.appleLanguageCode, "es")
        XCTAssertEqual(ScreenshotLanguage.spanish.appleLocaleIdentifier, "es_ES")

        XCTAssertEqual(ScreenshotLanguage.japanese.appleLanguageCode, "ja")
        XCTAssertEqual(ScreenshotLanguage.japanese.appleLocaleIdentifier, "ja_JP")

        XCTAssertEqual(ScreenshotLanguage.german.appleLanguageCode, "de")
        XCTAssertEqual(ScreenshotLanguage.german.appleLocaleIdentifier, "de_DE")
    }

    func testLanguageLaunchEnvironmentParsing() {
        let args = ["MyApp", "-SCREENSHOT_LANG", "zh"]
        let parsed = ScreenshotLanguage.fromLaunchEnvironment(arguments: args, environment: [:])
        XCTAssertEqual(parsed, .simplifiedChinese)

        let env = ["SCREENSHOT_LANG": "es"]
        let parsedEnv = ScreenshotLanguage.fromLaunchEnvironment(arguments: [], environment: env)
        XCTAssertEqual(parsedEnv, .spanish)
    }

    func testPresetProviderMatching() {
        XCTAssertEqual(MockPreset.from(token: "1"), .first)
        XCTAssertEqual(MockPreset.from(token: "2"), .second)
        XCTAssertEqual(MockPreset.from(token: "4b"), .celebration)
        XCTAssertEqual(MockPreset.from(token: "Feature One"), .first)
        XCTAssertEqual(MockPreset.from(token: "Streak Celebration"), .celebration)
        XCTAssertEqual(MockPreset.from(token: "nonexistent"), nil)
    }

    @MainActor
    func testEngineLaunchArguments() {
        let args = ["MyApp", "-SCREENSHOT_PRESET", "2", "-SCREENSHOT_LANG", "de"]
        let engine = ScreenshotEngine<MockPreset>(arguments: args, environment: [:])

        XCTAssertTrue(engine.isScreenshotCaptureActive)
        XCTAssertEqual(engine.activePreset, .second)
        XCTAssertEqual(engine.selectedLanguage, .german)
        XCTAssertEqual(engine.effectiveLanguage, .german)

        engine.reset()
        XCTAssertFalse(engine.isScreenshotCaptureActive)
        XCTAssertNil(engine.activePreset)
    }

    @MainActor
    func testDebugMenuViewWithScreenshotEngine() {
        let engine = ScreenshotEngine<MockPreset>(arguments: [], environment: [:])
        let menu = DebugMenuView(
            screenshotEngine: engine,
            onApplyScreenshotPreset: { _ in },
            onResetScreenshotPreset: { }
        )

        XCTAssertNotNil(menu.screenshotSection)
    }

    @MainActor
    func testDebugNavigationViewWithScreenshotEngine() {
        let engine = ScreenshotEngine<MockPreset>(arguments: [], environment: [:])
        let nav = DebugNavigationView(
            screenshotEngine: engine,
            onApplyScreenshotPreset: { _ in },
            onResetScreenshotPreset: { }
        )

        XCTAssertNotNil(nav.screenshotSection)
    }

    func testStandardScreenshotPreset() {
        XCTAssertEqual(StandardScreenshotPreset.allCases.count, 7)
        XCTAssertEqual(StandardScreenshotPreset.from(token: "1"), .slot1Benefit)
        XCTAssertEqual(StandardScreenshotPreset.from(token: "4b"), .slot4Celebration)
        XCTAssertEqual(StandardScreenshotPreset.from(token: "celebration"), .slot4Celebration)
        XCTAssertEqual(StandardScreenshotPreset.slot1Benefit.targetTabIndex, 0)
        XCTAssertEqual(StandardScreenshotPreset.slot2Feature.targetTabIndex, 1)
        XCTAssertEqual(StandardScreenshotPreset.slot3SecondFeature.targetTabIndex, 2)
        XCTAssertEqual(StandardScreenshotPreset.slot4Result.targetTabIndex, 3)
        XCTAssertEqual(StandardScreenshotPreset.slot5Settings.targetTabIndex, 4)
    }

    @MainActor
    func testEngineClosureCallbacksAndAutoTab() {
        let engine = ScreenshotEngine<StandardScreenshotPreset>(arguments: [], environment: [:])
        var appliedPreset: StandardScreenshotPreset?
        var resetCalled = false

        engine.onApply = { preset in
            appliedPreset = preset
        }
        engine.onReset = {
            resetCalled = true
        }

        engine.apply(preset: .slot2Feature)
        XCTAssertEqual(appliedPreset, .slot2Feature)
        XCTAssertEqual(engine.activePreset, .slot2Feature)

        var selectedTab = 0
        let binding = SwiftUI.Binding(get: { selectedTab }, set: { selectedTab = $0 })
        engine.tabIndexForPreset = { preset in
            preset == .slot2Feature ? 99 : nil
        }
        engine.handleAppLaunch(selectedTab: binding)
        XCTAssertEqual(selectedTab, 99)

        engine.reset()
        XCTAssertTrue(resetCalled)
        XCTAssertNil(engine.activePreset)
    }

    func testCoreDataInMemoryStoreSafetyCheck() {
        let model = NSManagedObjectModel()
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        _ = try? coordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)

        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        XCTAssertTrue(ScreenshotEngine<StandardScreenshotPreset>.isInMemoryStore(context: context))
    }

    func testAssumedForcedProWhenTakingScreenshots() {
        let screenshotArgs = ["MyApp", "-SCREENSHOT_PRESET", "1"]
        let normalArgs = ["MyApp"]

        XCTAssertTrue(DebugEntitlementOverride.isScreenshotCaptureActive(arguments: screenshotArgs, environment: [:]))
        XCTAssertFalse(DebugEntitlementOverride.isScreenshotCaptureActive(arguments: normalArgs, environment: [:]))

        // Normal launch: Automatic reflects storeStatus
        XCTAssertFalse(DebugEntitlementOverride.automatic.resolve(storeStatus: false, arguments: normalArgs, environment: [:]))
        XCTAssertTrue(DebugEntitlementOverride.automatic.resolve(storeStatus: true, arguments: normalArgs, environment: [:]))

        // Screenshot capture: Automatic assumes forced Pro
        XCTAssertTrue(DebugEntitlementOverride.automatic.resolve(storeStatus: false, arguments: screenshotArgs, environment: [:]))

        // Explicit forceFree still honors forceFree even if screenshots are active
        XCTAssertFalse(DebugEntitlementOverride.forceFree.resolve(storeStatus: true, arguments: screenshotArgs, environment: [:]))

        // Static helper with nil override assumes Pro during screenshots
        XCTAssertTrue(DebugEntitlementOverride.resolve(override: nil, storeStatus: false, arguments: screenshotArgs, environment: [:]))
        XCTAssertFalse(DebugEntitlementOverride.resolve(override: nil, storeStatus: false, arguments: normalArgs, environment: [:]))
    }

    @MainActor
    func testEngineConfiguresMarketingEntitlementOnLaunch() {
        let screenshotArgs = ["MyApp", "-SCREENSHOT_PRESET", "1"]
        let engine = ScreenshotEngine<StandardScreenshotPreset>(arguments: screenshotArgs, environment: [:])

        var override = DebugEntitlementOverride.automatic
        let binding = SwiftUI.Binding(get: { override }, set: { override = $0 })

        engine.handleAppLaunch(entitlementOverride: binding)
        XCTAssertEqual(override, .forcePro)
    }

    // MARK: - R1.1 Store Safety Gate & ScreenshotApplyResult

    #if canImport(CoreData)
    @MainActor
    func testCoreDataOnDiskAndEmptyStoresBlockedWithoutMutations() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenshotSafetyCoreData-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appendingPathComponent("Unsafe.sqlite")
        let model = NSManagedObjectModel()
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: nil
        )
        defer { try? coordinator.remove(store) }

        let diskContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        diskContext.persistentStoreCoordinator = coordinator

        XCTAssertFalse(ScreenshotEngine<MockPreset>.isInMemoryStore(context: diskContext))
        XCTAssertFalse(ScreenshotStoreSafety.isInMemoryStore(context: diskContext))

        let suiteName = "ScreenshotAutomationTests.\(UUID().uuidString)"
        let suite = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { suite.removePersistentDomain(forName: suiteName) }

        let originalEvaluated = ReleaseNotesManager.shared.hasEvaluatedLaunchReleaseNotes
        let originalShown = ReleaseNotesManager.hasShownReleaseNotesThisSession
        ReleaseNotesManager.shared.hasEvaluatedLaunchReleaseNotes = false
        ReleaseNotesManager.hasShownReleaseNotesThisSession = false
        defer {
            ReleaseNotesManager.shared.hasEvaluatedLaunchReleaseNotes = originalEvaluated
            ReleaseNotesManager.hasShownReleaseNotesThisSession = originalShown
        }

        let engine = ScreenshotEngine<MockPreset>(arguments: [], environment: [:])
        engine.environmentConfig = ScreenshotEnvironmentConfig(
            userDefaultsSuite: suite,
            defaultsOverrides: ["blockedKey": "shouldNotWrite"],
            suppressReleaseNotes: true
        )

        var onApplyCalled = false
        engine.onApply = { _ in onApplyCalled = true }
        let initialTriggerId = engine.navigationTriggerId

        let result = engine.apply(preset: .first, storeSafety: .coreData(diskContext))
        if case .blockedUnsafeStore(let reason) = result {
            XCTAssertFalse(reason.isEmpty)
        } else {
            XCTFail("Expected .blockedUnsafeStore, got \(result)")
        }

        XCTAssertFalse(onApplyCalled)
        XCTAssertNil(engine.activePreset)
        XCTAssertEqual(engine.navigationTriggerId, initialTriggerId)
        XCTAssertNil(suite.object(forKey: "blockedKey"))
        XCTAssertFalse(ReleaseNotesManager.shared.hasEvaluatedLaunchReleaseNotes)
        XCTAssertFalse(ReleaseNotesManager.hasShownReleaseNotesThisSession)

        // Empty coordinator (no persistent stores) and coordinator-less MOC must fail closed.
        let emptyCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let emptyContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        emptyContext.persistentStoreCoordinator = emptyCoordinator
        XCTAssertFalse(ScreenshotStoreSafety.isInMemoryStore(context: emptyContext))
        if case .blockedUnsafeStore = engine.apply(preset: .first, storeSafety: .coreData(emptyContext)) {
            // Expected
        } else {
            XCTFail("Expected empty CoreData coordinator to fail closed")
        }

        let orphanContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        XCTAssertFalse(ScreenshotStoreSafety.isInMemoryStore(context: orphanContext))
        if case .blockedUnsafeStore = engine.apply(preset: .first, storeSafety: .coreData(orphanContext)) {
            // Expected
        } else {
            XCTFail("Expected coordinator-less CoreData context to fail closed")
        }
    }

    @MainActor
    func testCoreDataDevNullAndAllowMockOverrideApply() throws {
        let model = NSManagedObjectModel()
        let devNullCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let devNullStore = try devNullCoordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: URL(fileURLWithPath: "/dev/null"),
            options: nil
        )
        defer { try? devNullCoordinator.remove(devNullStore) }

        let devNullContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        devNullContext.persistentStoreCoordinator = devNullCoordinator

        XCTAssertTrue(ScreenshotEngine<MockPreset>.isInMemoryStore(context: devNullContext))
        XCTAssertTrue(ScreenshotStoreSafety.isInMemoryStore(context: devNullContext))

        let engine = ScreenshotEngine<MockPreset>(arguments: ["MyApp", "-SCREENSHOT_LANG", "en"], environment: [:])
        var applyCount = 0
        engine.onApply = { _ in applyCount += 1 }

        let devNullResult = engine.apply(preset: .first, storeSafety: .coreData(devNullContext))
        XCTAssertEqual(devNullResult, .applied(presetId: "1", language: .english))
        XCTAssertEqual(applyCount, 1)

        // On-disk SQLite with allowMockOverride: true must succeed.
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenshotSafetyOverride-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let diskCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let diskStore = try diskCoordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: tempDir.appendingPathComponent("Override.sqlite"),
            options: nil
        )
        defer { try? diskCoordinator.remove(diskStore) }

        let diskContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        diskContext.persistentStoreCoordinator = diskCoordinator

        let overrideResult = engine.apply(
            preset: .second,
            storeSafety: .coreData(diskContext, allowMockOverride: true)
        )
        XCTAssertEqual(overrideResult, .applied(presetId: "2", language: .english))
        XCTAssertEqual(applyCount, 2)
    }
    #endif

    @MainActor
    func testSwiftDataStoreSafetyInMemoryVsPersistent() throws {
        #if canImport(SwiftData)
        guard #available(iOS 17, watchOS 10, *) else {
            throw XCTSkip("SwiftData requires iOS 17+ / watchOS 10+")
        }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenshotSafetySwiftData-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let diskConfig = ModelConfiguration(url: tempDir.appendingPathComponent("Unsafe.store"))
        let diskContainer = try ModelContainer(for: ScreenshotSafetyTestRecord.self, configurations: diskConfig)
        let diskContext = diskContainer.mainContext

        XCTAssertFalse(ScreenshotEngine<MockPreset>.isInMemoryStore(context: diskContext))
        XCTAssertFalse(ScreenshotStoreSafety.isInMemoryStore(context: diskContext))

        let engine = ScreenshotEngine<MockPreset>(arguments: ["MyApp", "-SCREENSHOT_LANG", "ja"], environment: [:])
        var appliedPresets: [MockPreset] = []
        engine.onApply = { appliedPresets.append($0) }

        let blocked = engine.apply(preset: .first, storeSafety: .swiftData(diskContext))
        if case .blockedUnsafeStore(let reason) = blocked {
            XCTAssertFalse(reason.isEmpty)
        } else {
            XCTFail("Expected .blockedUnsafeStore for persistent SwiftData container, got \(blocked)")
        }
        XCTAssertTrue(appliedPresets.isEmpty)
        XCTAssertNil(engine.activePreset)

        let overridden = engine.apply(
            preset: .first,
            storeSafety: .swiftData(diskContext, allowMockOverride: true)
        )
        XCTAssertEqual(overridden, .applied(presetId: "1", language: .japanese))
        XCTAssertEqual(appliedPresets, [.first])

        let memConfig = ModelConfiguration(isStoredInMemoryOnly: true)
        let memContainer = try ModelContainer(for: ScreenshotSafetyTestRecord.self, configurations: memConfig)
        let memContext = memContainer.mainContext

        XCTAssertTrue(ScreenshotEngine<MockPreset>.isInMemoryStore(context: memContext))
        XCTAssertTrue(ScreenshotStoreSafety.isInMemoryStore(context: memContext))

        let memResult = engine.apply(preset: .second, storeSafety: .swiftData(memContext))
        XCTAssertEqual(memResult, .applied(presetId: "2", language: .japanese))
        XCTAssertEqual(appliedPresets, [.first, .second])
        #else
        throw XCTSkip("SwiftData not available")
        #endif
    }

    @MainActor
    func testCustomStoreSafetyProviderAndDefaultStoreSafety() {
        let engine = ScreenshotEngine<MockPreset>(arguments: ["MyApp", "-SCREENSHOT_LANG", "en"], environment: [:])
        var applyCount = 0
        engine.onApply = { _ in applyCount += 1 }

        // Custom check failing
        let blocked = engine.apply(
            preset: .first,
            storeSafety: .custom("Mock mode disabled") { false }
        )
        XCTAssertEqual(blocked, .blockedUnsafeStore("Mock mode disabled"))
        XCTAssertEqual(applyCount, 0)

        // defaultStoreSafety fallback
        engine.defaultStoreSafety = .custom("Default safety blocked") { false }
        XCTAssertEqual(engine.apply(preset: .first), .blockedUnsafeStore("Default safety blocked"))
        XCTAssertEqual(applyCount, 0)

        // storeSafetyProvider overrides defaultStoreSafety
        engine.storeSafetyProvider = { .custom("Provider blocked") { false } }
        XCTAssertEqual(engine.apply(preset: .first), .blockedUnsafeStore("Provider blocked"))
        XCTAssertEqual(applyCount, 0)

        // Explicit storeSafety parameter overrides both provider and default
        let explicitPassed = engine.apply(
            preset: .second,
            storeSafety: .custom("Allowed") { true }
        )
        XCTAssertEqual(explicitPassed, .applied(presetId: "2", language: .english))
        XCTAssertEqual(applyCount, 1)
    }

    @MainActor
    func testHandleAppLaunchBlockedByUnsafeStoreHasZeroMutations() throws {
        let suiteName = "ScreenshotAutomationTests.\(UUID().uuidString)"
        let suite = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { suite.removePersistentDomain(forName: suiteName) }

        let engine = ScreenshotEngine<MockPreset>(
            arguments: ["MyApp", "-SCREENSHOT_PRESET", "2", "-SCREENSHOT_LANG", "en"],
            environment: [:]
        )
        engine.environmentConfig = ScreenshotEnvironmentConfig(
            userDefaultsSuite: suite,
            defaultsOverrides: ["launchBlockedKey": true],
            suppressReleaseNotes: false
        )

        var selectedTab = 0
        let tabBinding = Binding(get: { selectedTab }, set: { selectedTab = $0 })
        var onApplyCalled = false
        engine.onApply = { _ in onApplyCalled = true }
        let initialTriggerId = engine.navigationTriggerId

        let result = engine.handleAppLaunch(
            selectedTab: tabBinding,
            storeSafety: .custom("Unsafe store on launch") { false }
        )

        XCTAssertEqual(result, .blockedUnsafeStore("Unsafe store on launch"))
        XCTAssertFalse(engine.hasAppliedLaunchPreset)
        XCTAssertFalse(onApplyCalled)
        XCTAssertEqual(selectedTab, 0)
        XCTAssertEqual(engine.navigationTriggerId, initialTriggerId)
        XCTAssertNil(suite.object(forKey: "launchBlockedKey"))
    }

    // MARK: - R1.2 One-Shot Launch Guard & Re-entrancy

    @MainActor
    func testOneShotLaunchGuardAutoApplyFalseAndReset() {
        let engine = ScreenshotEngine<MockPreset>(
            arguments: ["MyApp", "-SCREENSHOT_PRESET", "2", "-SCREENSHOT_LANG", "en"],
            environment: [:]
        )
        var applyCount = 0
        engine.onApply = { _ in applyCount += 1 }

        var selectedTab = 0
        let tabBinding = Binding(get: { selectedTab }, set: { selectedTab = $0 })

        XCTAssertFalse(engine.hasAppliedLaunchPreset)

        // autoApply: false navigates without applying or locking out subsequent launch apply
        let previewResult = engine.handleAppLaunch(selectedTab: tabBinding, autoApply: false)
        XCTAssertEqual(previewResult, .noPreset)
        XCTAssertEqual(selectedTab, 1)
        XCTAssertEqual(applyCount, 0)
        XCTAssertFalse(engine.hasAppliedLaunchPreset)

        // First autoApply: true applies and locks launch guard
        selectedTab = 0
        let firstResult = engine.handleAppLaunch(selectedTab: tabBinding)
        XCTAssertEqual(firstResult, .applied(presetId: "2", language: .english))
        XCTAssertTrue(engine.hasAppliedLaunchPreset)
        XCTAssertEqual(applyCount, 1)
        XCTAssertEqual(selectedTab, 1)

        // User manually switches tab; second handleAppLaunch is a no-op
        selectedTab = 99
        let secondResult = engine.handleAppLaunch(selectedTab: tabBinding)
        XCTAssertEqual(secondResult, .noPreset)
        XCTAssertEqual(applyCount, 1)
        XCTAssertEqual(selectedTab, 99)

        // reset() clears hasAppliedLaunchPreset
        engine.reset()
        XCTAssertFalse(engine.hasAppliedLaunchPreset)
        XCTAssertNil(engine.activePreset)
    }

    @MainActor
    func testHandleAppLaunchReentrancyProtection() {
        let engine = ScreenshotEngine<MockPreset>(
            arguments: ["MyApp", "-SCREENSHOT_PRESET", "1", "-SCREENSHOT_LANG", "en"],
            environment: [:]
        )
        var selectedTab = 5
        let tabBinding = Binding(get: { selectedTab }, set: { selectedTab = $0 })

        var applyCount = 0
        var reentrantResult: ScreenshotApplyResult?
        engine.onApply = { _ in
            applyCount += 1
            reentrantResult = engine.handleAppLaunch(selectedTab: tabBinding)
        }

        let result = engine.handleAppLaunch(selectedTab: tabBinding)
        XCTAssertEqual(result, .applied(presetId: "1", language: .english))
        XCTAssertEqual(reentrantResult, .noPreset)
        XCTAssertEqual(applyCount, 1)
        XCTAssertTrue(engine.hasAppliedLaunchPreset)
        XCTAssertEqual(selectedTab, 0)
    }

    @MainActor
    func testNormalLaunchDoesNotLockOutManualApply() {
        let engine = ScreenshotEngine<MockPreset>(
            arguments: ["MyApp", "-SCREENSHOT_LANG", "en"],
            environment: [:]
        )
        var applied: [MockPreset] = []
        engine.onApply = { applied.append($0) }

        let launchResult = engine.handleAppLaunch()
        XCTAssertEqual(launchResult, .noPreset)
        XCTAssertFalse(engine.hasAppliedLaunchPreset)
        XCTAssertTrue(applied.isEmpty)

        let manualResult = engine.apply(preset: .second)
        XCTAssertEqual(manualResult, .applied(presetId: "2", language: .english))
        XCTAssertEqual(applied, [.second])
    }

    @MainActor
    func testAssumeForcedProAndForceFreePrecedence() {
        // 1. assumeForcedPro = false leaves .automatic untouched
        let noAutoProEngine = ScreenshotEngine<MockPreset>(
            arguments: ["MyApp", "-SCREENSHOT_PRESET", "1"],
            environment: [:]
        )
        noAutoProEngine.assumeForcedPro = false
        var overrideNoAuto = DebugEntitlementOverride.automatic
        noAutoProEngine.handleAppLaunch(
            entitlementOverride: Binding(get: { overrideNoAuto }, set: { overrideNoAuto = $0 })
        )
        XCTAssertEqual(overrideNoAuto, .automatic)

        // 2. -FORCE_FREE argument prevents forcing .forcePro when override starts as .forceFree or .automatic
        let forceFreeEngine = ScreenshotEngine<MockPreset>(
            arguments: ["MyApp", "-SCREENSHOT_PRESET", "1", "-FORCE_FREE"],
            environment: [:]
        )
        var explicitFree = DebugEntitlementOverride.forceFree
        forceFreeEngine.handleAppLaunch(
            entitlementOverride: Binding(get: { explicitFree }, set: { explicitFree = $0 })
        )
        XCTAssertEqual(explicitFree, .forceFree)

        let forceFreeAutoEngine = ScreenshotEngine<MockPreset>(
            arguments: ["MyApp", "-SCREENSHOT_PRESET", "1", "-FORCE_FREE"],
            environment: [:]
        )
        var autoWithFreeFlag = DebugEntitlementOverride.automatic
        forceFreeAutoEngine.handleAppLaunch(
            entitlementOverride: Binding(get: { autoWithFreeFlag }, set: { autoWithFreeFlag = $0 })
        )
        XCTAssertNotEqual(autoWithFreeFlag, .forcePro)

        // 3. Already-.forceFree binding is respected even without -FORCE_FREE argument
        let regularScreenshotEngine = ScreenshotEngine<MockPreset>(
            arguments: ["MyApp", "-SCREENSHOT_PRESET", "1"],
            environment: [:]
        )
        var preSetForceFree = DebugEntitlementOverride.forceFree
        regularScreenshotEngine.handleAppLaunch(
            entitlementOverride: Binding(get: { preSetForceFree }, set: { preSetForceFree = $0 })
        )
        XCTAssertEqual(preSetForceFree, .forceFree)
    }

    // MARK: - R1.3 Scoped & Reversible Environment Snapshot / Restore

    @MainActor
    func testEnvironmentConfigSnapshotAndRestoreOnReset() throws {
        let suiteName = "ScreenshotAutomationTests.\(UUID().uuidString)"
        let suite = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { suite.removePersistentDomain(forName: suiteName) }

        suite.set("kg", forKey: "unitSystem")
        suite.set(false, forKey: "existingFalseFlag")
        suite.set(42, forKey: "existingInt")
        suite.set("toBeRemovedTemporarily", forKey: "nullableKey")
        // "previouslyAbsentKey" intentionally left unset

        let originalEvaluated = ReleaseNotesManager.shared.hasEvaluatedLaunchReleaseNotes
        let originalShown = ReleaseNotesManager.hasShownReleaseNotesThisSession
        ReleaseNotesManager.shared.hasEvaluatedLaunchReleaseNotes = false
        ReleaseNotesManager.hasShownReleaseNotesThisSession = false
        defer {
            ReleaseNotesManager.shared.hasEvaluatedLaunchReleaseNotes = originalEvaluated
            ReleaseNotesManager.hasShownReleaseNotesThisSession = originalShown
        }

        let engine = ScreenshotEngine<MockPreset>(arguments: ["MyApp", "-SCREENSHOT_LANG", "en"], environment: [:])
        engine.environmentConfig = ScreenshotEnvironmentConfig(
            userDefaultsSuite: suite,
            defaultsOverrides: [
                "unitSystem": "lbs",
                "existingFalseFlag": true,
                "existingInt": 99,
                "previouslyAbsentKey": "demoValue",
                "nullableKey": NSNull()
            ],
            suppressReleaseNotes: true
        )

        let applyResult = engine.apply(preset: .first)
        XCTAssertEqual(applyResult, .applied(presetId: "1", language: .english))
        XCTAssertEqual(suite.string(forKey: "unitSystem"), "lbs")
        XCTAssertEqual(suite.object(forKey: "existingFalseFlag") as? Bool, true)
        XCTAssertEqual(suite.object(forKey: "existingInt") as? Int, 99)
        XCTAssertEqual(suite.string(forKey: "previouslyAbsentKey"), "demoValue")
        XCTAssertNil(suite.object(forKey: "nullableKey"))
        XCTAssertTrue(ReleaseNotesManager.shared.hasEvaluatedLaunchReleaseNotes)
        XCTAssertTrue(ReleaseNotesManager.hasShownReleaseNotesThisSession)

        engine.reset()

        XCTAssertEqual(suite.string(forKey: "unitSystem"), "kg")
        XCTAssertNotNil(suite.object(forKey: "existingFalseFlag"))
        XCTAssertEqual(suite.object(forKey: "existingFalseFlag") as? Bool, false)
        XCTAssertEqual(suite.object(forKey: "existingInt") as? Int, 42)
        XCTAssertNil(suite.object(forKey: "previouslyAbsentKey"))
        XCTAssertEqual(suite.string(forKey: "nullableKey"), "toBeRemovedTemporarily")
        XCTAssertFalse(ReleaseNotesManager.shared.hasEvaluatedLaunchReleaseNotes)
        XCTAssertFalse(ReleaseNotesManager.hasShownReleaseNotesThisSession)
        // environmentConfig itself must survive reset() for subsequent Debug Menu applies
        XCTAssertEqual(engine.environmentConfig.defaultsOverrides["unitSystem"] as? String, "lbs")
    }

    @MainActor
    func testEnvironmentConfigPreservesOriginalSnapshotAcrossPresetSwitchesAndSuppressFalse() throws {
        let suiteName = "ScreenshotAutomationTests.\(UUID().uuidString)"
        let suite = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { suite.removePersistentDomain(forName: suiteName) }

        suite.set("originalMode", forKey: "mode")
        suite.set("originalExtra", forKey: "extraKey")

        let originalEvaluated = ReleaseNotesManager.shared.hasEvaluatedLaunchReleaseNotes
        let originalShown = ReleaseNotesManager.hasShownReleaseNotesThisSession
        ReleaseNotesManager.shared.hasEvaluatedLaunchReleaseNotes = false
        ReleaseNotesManager.hasShownReleaseNotesThisSession = false
        defer {
            ReleaseNotesManager.shared.hasEvaluatedLaunchReleaseNotes = originalEvaluated
            ReleaseNotesManager.hasShownReleaseNotesThisSession = originalShown
        }

        let engine = ScreenshotEngine<MockPreset>(arguments: [], environment: [:])
        engine.environmentConfig = ScreenshotEnvironmentConfig(
            userDefaultsSuite: suite,
            defaultsOverrides: ["mode": "preset1Mode"],
            suppressReleaseNotes: false
        )

        engine.apply(preset: .first)
        XCTAssertEqual(suite.string(forKey: "mode"), "preset1Mode")
        XCTAssertFalse(ReleaseNotesManager.shared.hasEvaluatedLaunchReleaseNotes)
        XCTAssertFalse(ReleaseNotesManager.hasShownReleaseNotesThisSession)

        // Mutate overrides for second preset before resetting
        engine.environmentConfig.defaultsOverrides = [
            "mode": "preset2Mode",
            "extraKey": "preset2Extra",
            "newOnSecond": 7
        ]
        engine.apply(preset: .second)
        XCTAssertEqual(suite.string(forKey: "mode"), "preset2Mode")
        XCTAssertEqual(suite.string(forKey: "extraKey"), "preset2Extra")
        XCTAssertEqual(suite.object(forKey: "newOnSecond") as? Int, 7)

        engine.reset()
        XCTAssertEqual(suite.string(forKey: "mode"), "originalMode")
        XCTAssertEqual(suite.string(forKey: "extraKey"), "originalExtra")
        XCTAssertNil(suite.object(forKey: "newOnSecond"))
    }

    // MARK: - R1.4 Collision-Free 3-Tier Token Resolution & Launch Parsing

    func testTokenResolutionThreeTierPriority() {
        // Tier 1 (exact rawValue/id) beats Tier 2 (aliases) and Tier 3 (title/filename substring)
        XCTAssertEqual(OverlapTokenPreset.from(token: "beta"), .beta)
        XCTAssertEqual(OverlapTokenPreset.from(token: "  BETA  "), .beta)

        // Tier 2 (exact alias) beats Tier 3 (title/filename substring on another case)
        XCTAssertEqual(OverlapTokenPreset.from(token: "gamma"), .alpha)
        XCTAssertEqual(OverlapTokenPreset.from(token: "  GaMmA "), .alpha)
        XCTAssertEqual(OverlapTokenPreset.from(token: "alpha_alias"), .beta)
        XCTAssertEqual(OverlapTokenPreset.from(token: "beta_alias"), .gamma)

        // Tier 3 (substring fallback on title / suggestedFilename)
        XCTAssertEqual(OverlapTokenPreset.from(token: "Details"), .beta)
        XCTAssertEqual(OverlapTokenPreset.from(token: "03 - Gamma"), .gamma)

        // Custom id matching when id != rawValue
        XCTAssertEqual(CustomIdPreset.from(token: "custom_id_alpha"), .first)
        XCTAssertEqual(CustomIdPreset.from(token: "CUSTOM_ID_BETA"), .second)
        XCTAssertEqual(CustomIdPreset.from(token: "raw_first"), .first)

        // Empty / whitespace-only / unknown tokens must return nil
        XCTAssertNil(OverlapTokenPreset.from(token: ""))
        XCTAssertNil(OverlapTokenPreset.from(token: "   \n\t "))
        XCTAssertNil(OverlapTokenPreset.from(token: "missing_token"))
    }

    func testStandardPresetAliasesAndFromLaunchEnvironment() {
        for preset in StandardScreenshotPreset.allCases {
            XCTAssertFalse(preset.aliases.isEmpty, "Missing aliases on \(preset)")
        }

        // All legacy StandardScreenshotPreset aliases resolve without collisions
        XCTAssertEqual(StandardScreenshotPreset.from(token: "benefit"), .slot1Benefit)
        XCTAssertEqual(StandardScreenshotPreset.from(token: "main"), .slot1Benefit)
        XCTAssertEqual(StandardScreenshotPreset.from(token: "feature"), .slot2Feature)
        XCTAssertEqual(StandardScreenshotPreset.from(token: "top"), .slot2Feature)
        XCTAssertEqual(StandardScreenshotPreset.from(token: "secondary"), .slot3SecondFeature)
        XCTAssertEqual(StandardScreenshotPreset.from(token: "notes"), .slot3SecondFeature)
        XCTAssertEqual(StandardScreenshotPreset.from(token: "history"), .slot3SecondFeature)
        XCTAssertEqual(StandardScreenshotPreset.from(token: "4a"), .slot4Result)
        XCTAssertEqual(StandardScreenshotPreset.from(token: "result"), .slot4Result)
        XCTAssertEqual(StandardScreenshotPreset.from(token: "calendar"), .slot4Result)
        XCTAssertEqual(StandardScreenshotPreset.from(token: "stats"), .slot4Result)
        XCTAssertEqual(StandardScreenshotPreset.from(token: "celebration"), .slot4Celebration)
        XCTAssertEqual(StandardScreenshotPreset.from(token: "milestone"), .slot4Celebration)
        XCTAssertEqual(StandardScreenshotPreset.from(token: "modal"), .slot4Celebration)
        XCTAssertEqual(StandardScreenshotPreset.from(token: "5a"), .slot5Customization)
        XCTAssertEqual(StandardScreenshotPreset.from(token: "custom"), .slot5Customization)
        XCTAssertEqual(StandardScreenshotPreset.from(token: "goals"), .slot5Customization)
        XCTAssertEqual(StandardScreenshotPreset.from(token: "settings"), .slot5Settings)
        XCTAssertEqual(StandardScreenshotPreset.from(token: "pro"), .slot5Settings)

        // Launch argument & environment parsing
        XCTAssertEqual(
            StandardScreenshotPreset.fromLaunchEnvironment(
                arguments: ["MyApp", "-SCREENSHOT_PRESET", "4a"],
                environment: ["SCREENSHOT_PRESET": "1"]
            ),
            .slot4Result
        )
        XCTAssertEqual(
            StandardScreenshotPreset.fromLaunchEnvironment(
                arguments: ["MyApp", "-screenshotPreset", "pro"],
                environment: [:]
            ),
            .slot5Settings
        )
        XCTAssertEqual(
            StandardScreenshotPreset.fromLaunchEnvironment(
                arguments: ["MyApp"],
                environment: ["SCREENSHOT_PRESET": "celebration"]
            ),
            .slot4Celebration
        )
        XCTAssertNil(
            StandardScreenshotPreset.fromLaunchEnvironment(
                arguments: ["MyApp", "-SCREENSHOT_PRESET"],
                environment: [:]
            )
        )
    }

    // MARK: - R1.5 Release Safety (#if DEBUG Gating)

    @MainActor
    func testReleaseGatingBehaviorAndPublicAPIAvailability() throws {
        let suiteName = "ScreenshotAutomationTests.\(UUID().uuidString)"
        let suite = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { suite.removePersistentDomain(forName: suiteName) }

        let args = ["MyApp", "-SCREENSHOT_PRESET", "2", "-SCREENSHOT_LANG", "de"]
        let env = ["SCREENSHOT_PRESET": "1"]
        let engine = ScreenshotEngine<MockPreset>(arguments: args, environment: env)
        engine.environmentConfig = ScreenshotEnvironmentConfig(
            userDefaultsSuite: suite,
            defaultsOverrides: ["releaseGateKey": "applied"],
            suppressReleaseNotes: false
        )

        var applyCount = 0
        var resetCount = 0
        engine.onApply = { _ in applyCount += 1 }
        engine.onReset = { resetCount += 1 }

        let parsedFromPreset = MockPreset.fromLaunchEnvironment(arguments: args, environment: env)
        let parsedFromEngine = ScreenshotEngine<MockPreset>.parseLaunchPreset(arguments: args, environment: env)
        let launchResult = engine.handleAppLaunch()
        let manualResult = engine.apply(preset: .first)

        // Ensure view modifier compiles in both Debug and Release
        var tabInt = 0
        let intBinding = Binding(get: { tabInt }, set: { tabInt = $0 })
        _ = Text("ReleaseCheck").screenshotTabCoordination(engine: engine, selectedTab: intBinding)

        #if DEBUG
        XCTAssertEqual(parsedFromPreset, .second)
        XCTAssertEqual(parsedFromEngine, .second)
        XCTAssertEqual(launchResult, .applied(presetId: "2", language: .german))
        XCTAssertEqual(manualResult, .applied(presetId: "1", language: .german))
        XCTAssertEqual(applyCount, 2)
        XCTAssertTrue(engine.isScreenshotCaptureActive)
        XCTAssertEqual(suite.string(forKey: "releaseGateKey"), "applied")

        engine.reset()
        XCTAssertEqual(resetCount, 1)
        XCTAssertNil(suite.object(forKey: "releaseGateKey"))
        #else
        XCTAssertNil(parsedFromPreset)
        XCTAssertNil(parsedFromEngine)
        XCTAssertEqual(launchResult, .noPreset)
        XCTAssertEqual(manualResult, .noPreset)
        XCTAssertEqual(applyCount, 0)
        XCTAssertFalse(engine.isScreenshotCaptureActive)
        XCTAssertNil(engine.activePreset)
        XCTAssertEqual(engine.selectedLanguage, .auto)
        XCTAssertNil(suite.object(forKey: "releaseGateKey"))

        engine.reset()
        XCTAssertEqual(resetCount, 0)
        #endif
    }

    // MARK: - R1.6 Navigation Trigger & SwiftUI Tab Coordination

    @MainActor
    func testNavigationTriggerIdUpdatesOnApplyAndResetOnly() {
        let engine = ScreenshotEngine<MockPreset>(
            arguments: ["MyApp", "-SCREENSHOT_PRESET", "1"],
            environment: [:]
        )

        let id0 = engine.navigationTriggerId
        _ = engine.apply(preset: .first, storeSafety: .custom("Blocked") { false })
        XCTAssertEqual(engine.navigationTriggerId, id0)

        _ = engine.handleAppLaunch(autoApply: false)
        let id1 = engine.navigationTriggerId
        XCTAssertNotEqual(id1, id0)

        _ = engine.apply(preset: .second)
        let id2 = engine.navigationTriggerId
        XCTAssertNotEqual(id2, id1)

        engine.reset()
        let id3 = engine.navigationTriggerId
        XCTAssertNotEqual(id3, id2)
    }

    #if canImport(UIKit)
    @MainActor
    func testScreenshotTabCoordinationIntAndHashableBindings() {
        // 1. Int-backed Tab coordination
        let intEngine = ScreenshotEngine<MockPreset>(
            arguments: ["MyApp", "-SCREENSHOT_PRESET", "2"],
            environment: [:]
        )
        var selectedIntTab = 0
        let intBinding = Binding(get: { selectedIntTab }, set: { selectedIntTab = $0 })

        let intHost = UIHostingController(
            rootView: TabCoordIntTestView(
                engine: intEngine,
                selectedTab: intBinding,
                tabForPreset: nil
            )
        )
        let intWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        intWindow.rootViewController = intHost
        intWindow.makeKeyAndVisible()
        defer {
            intWindow.isHidden = true
            intWindow.rootViewController = nil
        }
        intHost.view.setNeedsLayout()
        intHost.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        // .onAppear syncs initial activePreset (.second -> targetTabIndex 1)
        XCTAssertEqual(selectedIntTab, 1)

        // Switching preset updates tab
        intEngine.apply(preset: .celebration)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(selectedIntTab, 2)

        // Manual tab change followed by re-applying the SAME preset (navigationTriggerId) snaps back
        selectedIntTab = 0
        intEngine.apply(preset: .celebration)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(selectedIntTab, 2)

        // Reset keeps selectedTab intact (does not spuriously jump)
        intEngine.reset()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(selectedIntTab, 2)

        // 2. Generic Tab: Hashable coordination + nil mapping handling
        let hashEngine = ScreenshotEngine<MockPreset>(arguments: [], environment: [:])
        var selectedHashTab: TestTab = .home
        let hashBinding = Binding(get: { selectedHashTab }, set: { selectedHashTab = $0 })

        let hashHost = UIHostingController(
            rootView: TabCoordHashableTestView(
                engine: hashEngine,
                selectedTab: hashBinding,
                tabForPreset: { preset in
                    switch preset {
                    case .first: return .home
                    case .second: return .trends
                    case .celebration: return nil
                    }
                }
            )
        )
        let hashWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        hashWindow.rootViewController = hashHost
        hashWindow.makeKeyAndVisible()
        defer {
            hashWindow.isHidden = true
            hashWindow.rootViewController = nil
        }
        hashHost.view.setNeedsLayout()
        hashHost.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        hashEngine.apply(preset: .second)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(selectedHashTab, .trends)

        // nil mapping leaves current tab unchanged
        hashEngine.apply(preset: .celebration)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(selectedHashTab, .trends)
    }

    @MainActor
    func testScreenshotTabCoordinationIntExplicitNilVsOmittedDefault() {
        // 1. Explicit tabForPreset returning nil leaves selectedTab untouched (even when engine.tabIndexForPreset & preset.targetTabIndex are non-nil)
        let explicitEngine = ScreenshotEngine<MockPreset>(arguments: [], environment: [:])
        explicitEngine.tabIndexForPreset = { _ in 77 }
        var explicitTab = 99
        let explicitBinding = Binding(get: { explicitTab }, set: { explicitTab = $0 })

        let explicitHost = UIHostingController(
            rootView: TabCoordIntTestView(
                engine: explicitEngine,
                selectedTab: explicitBinding,
                tabForPreset: { preset in
                    preset == .second ? nil : preset.targetTabIndex
                }
            )
        )
        let explicitWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        explicitWindow.rootViewController = explicitHost
        explicitWindow.makeKeyAndVisible()
        defer {
            explicitWindow.isHidden = true
            explicitWindow.rootViewController = nil
        }
        explicitHost.view.setNeedsLayout()
        explicitHost.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        explicitEngine.apply(preset: .second)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(explicitTab, 99)

        explicitEngine.apply(preset: .celebration)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(explicitTab, 2)

        // 2. Omitting tabForPreset (default nil) falls back to engine.tabIndexForPreset then preset.targetTabIndex
        let defaultEngine = ScreenshotEngine<MockPreset>(arguments: [], environment: [:])
        defaultEngine.tabIndexForPreset = { preset in
            preset == .first ? 42 : nil
        }
        var defaultTab = 99
        let defaultBinding = Binding(get: { defaultTab }, set: { defaultTab = $0 })

        let defaultHost = UIHostingController(
            rootView: TabCoordIntDefaultTestView(
                engine: defaultEngine,
                selectedTab: defaultBinding
            )
        )
        let defaultWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        defaultWindow.rootViewController = defaultHost
        defaultWindow.makeKeyAndVisible()
        defer {
            defaultWindow.isHidden = true
            defaultWindow.rootViewController = nil
        }
        defaultHost.view.setNeedsLayout()
        defaultHost.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        defaultEngine.apply(preset: .first)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(defaultTab, 42)

        defaultEngine.apply(preset: .second)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(defaultTab, 1)
    }
    #endif

    // MARK: - Iteration 2 Regression Tests

    @MainActor
    func testHandleAppLaunchBlockedAndRepeatCallDoNotMutateEntitlementOverride() {
        let engine = ScreenshotEngine<MockPreset>(
            arguments: ["MyApp", "-SCREENSHOT_PRESET", "2", "-SCREENSHOT_LANG", "en"],
            environment: [:]
        )

        var selectedTab = 7
        let tabBinding = Binding(get: { selectedTab }, set: { selectedTab = $0 })
        var entitlement = DebugEntitlementOverride.automatic
        let entitlementBinding = Binding(get: { entitlement }, set: { entitlement = $0 })

        var safetyAllowed = false
        engine.storeSafetyProvider = {
            .custom("Blocked store on launch") { safetyAllowed }
        }
        var applyCount = 0
        engine.onApply = { _ in applyCount += 1 }

        // 1. Blocked store must leave entitlementOverride, hasAppliedLaunchPreset, and selectedTab untouched
        let blockedResult = engine.handleAppLaunch(
            selectedTab: tabBinding,
            entitlementOverride: entitlementBinding
        )
        XCTAssertEqual(blockedResult, .blockedUnsafeStore("Blocked store on launch"))
        XCTAssertEqual(entitlement, .automatic)
        XCTAssertFalse(engine.hasAppliedLaunchPreset)
        XCTAssertEqual(selectedTab, 7)
        XCTAssertEqual(applyCount, 0)

        // 2. Subsequent safe launch applies and updates entitlementOverride to .forcePro
        safetyAllowed = true
        let appliedResult = engine.handleAppLaunch(
            selectedTab: tabBinding,
            entitlementOverride: entitlementBinding
        )
        XCTAssertEqual(appliedResult, .applied(presetId: "2", language: .english))
        XCTAssertEqual(entitlement, .forcePro)
        XCTAssertTrue(engine.hasAppliedLaunchPreset)
        XCTAssertEqual(selectedTab, 1)
        XCTAssertEqual(applyCount, 1)

        // 3. Second handleAppLaunch while hasAppliedLaunchPreset == true must not mutate entitlementOverride
        entitlement = .automatic
        selectedTab = 99
        let repeatResult = engine.handleAppLaunch(
            selectedTab: tabBinding,
            entitlementOverride: entitlementBinding
        )
        XCTAssertEqual(repeatResult, .noPreset)
        XCTAssertEqual(entitlement, .automatic)
        XCTAssertEqual(selectedTab, 99)
        XCTAssertEqual(applyCount, 1)

        // 4. -SCREENSHOT_CAPTURE without -SCREENSHOT_PRESET configures entitlementOverride and returns .noPreset
        let captureOnlyEngine = ScreenshotEngine<MockPreset>(
            arguments: ["MyApp", "-SCREENSHOT_CAPTURE"],
            environment: [:]
        )
        var captureEntitlement = DebugEntitlementOverride.automatic
        let captureEntitlementBinding = Binding(get: { captureEntitlement }, set: { captureEntitlement = $0 })
        let captureResult = captureOnlyEngine.handleAppLaunch(entitlementOverride: captureEntitlementBinding)
        XCTAssertEqual(captureResult, .noPreset)
        XCTAssertEqual(captureEntitlement, .forcePro)
        XCTAssertFalse(captureOnlyEngine.hasAppliedLaunchPreset)
    }

    @MainActor
    func testHandleAppLaunchEvaluatesStoreSafetyProviderOnce() {
        // Safe path: flipping provider to fail on 2nd evaluation proves single evaluation (no TOCTOU)
        let safeEngine = ScreenshotEngine<MockPreset>(
            arguments: ["MyApp", "-SCREENSHOT_PRESET", "2", "-SCREENSHOT_LANG", "en"],
            environment: [:]
        )
        var safeProviderEvalCount = 0
        var safeValidateCount = 0
        safeEngine.storeSafetyProvider = {
            safeProviderEvalCount += 1
            let currentCall = safeProviderEvalCount
            return .custom("Flipped unsafe on call \(currentCall)") {
                safeValidateCount += 1
                return currentCall == 1
            }
        }
        var applyCount = 0
        safeEngine.onApply = { _ in applyCount += 1 }

        var selectedTab = 0
        let tabBinding = Binding(get: { selectedTab }, set: { selectedTab = $0 })
        let safeResult = safeEngine.handleAppLaunch(selectedTab: tabBinding)

        XCTAssertEqual(safeResult, .applied(presetId: "2", language: .english))
        XCTAssertEqual(safeProviderEvalCount, 1)
        XCTAssertEqual(safeValidateCount, 1)
        XCTAssertTrue(safeEngine.hasAppliedLaunchPreset)
        XCTAssertEqual(selectedTab, 1)
        XCTAssertEqual(applyCount, 1)

        // Blocked path also evaluates storeSafetyProvider and validate() exactly once
        let blockedEngine = ScreenshotEngine<MockPreset>(
            arguments: ["MyApp", "-SCREENSHOT_PRESET", "1", "-SCREENSHOT_LANG", "en"],
            environment: [:]
        )
        var blockedProviderEvalCount = 0
        var blockedValidateCount = 0
        blockedEngine.storeSafetyProvider = {
            blockedProviderEvalCount += 1
            return .custom("Unsafe once") {
                blockedValidateCount += 1
                return false
            }
        }
        var blockedTab = 5
        var blockedEnt = DebugEntitlementOverride.automatic
        let blockedResult = blockedEngine.handleAppLaunch(
            selectedTab: Binding(get: { blockedTab }, set: { blockedTab = $0 }),
            entitlementOverride: Binding(get: { blockedEnt }, set: { blockedEnt = $0 })
        )

        XCTAssertEqual(blockedResult, .blockedUnsafeStore("Unsafe once"))
        XCTAssertEqual(blockedProviderEvalCount, 1)
        XCTAssertEqual(blockedValidateCount, 1)
        XCTAssertFalse(blockedEngine.hasAppliedLaunchPreset)
        XCTAssertEqual(blockedTab, 5)
        XCTAssertEqual(blockedEnt, .automatic)
    }

    @MainActor
    func testEnvironmentConfigURLOverridesSnapshotAndRestore() throws {
        let suiteName = "ScreenshotAutomationTests.\(UUID().uuidString)"
        let suite = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { suite.removePersistentDomain(forName: suiteName) }

        let originalWebURL = try XCTUnwrap(URL(string: "https://example.com/original"))
        let originalFileURL = URL(fileURLWithPath: "/tmp/original-screenshot.json")
        suite.set(originalWebURL, forKey: "existingWebURL")
        suite.set(originalFileURL, forKey: "existingFileURL")
        // "absentURL" intentionally left unset

        let overrideWebURL = try XCTUnwrap(URL(string: "https://demo.example.com/marketing"))
        let overrideFileURL = URL(fileURLWithPath: "/tmp/demo-screenshot.json")
        let absentOverrideURL = try XCTUnwrap(URL(string: "https://demo.example.com/new"))

        let engine = ScreenshotEngine<MockPreset>(arguments: ["MyApp", "-SCREENSHOT_LANG", "en"], environment: [:])
        engine.environmentConfig = ScreenshotEnvironmentConfig(
            userDefaultsSuite: suite,
            defaultsOverrides: [
                "existingWebURL": overrideWebURL,
                "existingFileURL": overrideFileURL,
                "absentURL": absentOverrideURL
            ],
            suppressReleaseNotes: false
        )

        let result = engine.apply(preset: .first)
        XCTAssertEqual(result, .applied(presetId: "1", language: .english))
        XCTAssertEqual(suite.url(forKey: "existingWebURL"), overrideWebURL)
        XCTAssertEqual(suite.url(forKey: "existingFileURL"), overrideFileURL)
        XCTAssertEqual(suite.url(forKey: "absentURL"), absentOverrideURL)

        engine.reset()
        XCTAssertEqual(suite.url(forKey: "existingWebURL"), originalWebURL)
        XCTAssertEqual(suite.url(forKey: "existingFileURL"), originalFileURL)
        XCTAssertNil(suite.url(forKey: "absentURL"))
        XCTAssertNil(suite.object(forKey: "absentURL"))
    }
}
