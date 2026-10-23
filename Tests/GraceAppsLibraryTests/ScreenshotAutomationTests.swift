//
//  ScreenshotAutomationTests.swift
//  GraceAppsLibraryTests
//
//  Created by Antigravity on 10/23/26.
//

import XCTest
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
}
