//
//  ScreenshotAutomationTests.swift
//  GraceAppsLibraryTests
//
//  Created by Antigravity on 10/23/26.
//

import XCTest
import SwiftUI
import CoreData
@testable import GraceAppsLibrary

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
}

final class ScreenshotAutomationTests: XCTestCase {

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
}
