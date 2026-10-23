//
//  StandardScreenshotPreset.swift
//  GraceAppsLibrary
//
//  Created by Antigravity on 10/23/26.
//

import Foundation

/// Standard 7-slot App Store screenshot presets used across GraceApps.
///
/// Follows the recommended App Store flow:
/// 1. Slot #1 • Main Benefit
/// 2. Slot #2 • Top Feature
/// 3. Slot #3 • Secondary Feature
/// 4. Slot #4A • Realistic Result (Consistency / Stats)
/// 5. Slot #4B • Milestone / Paywall / Celebration Modal
/// 6. Slot #5A • Differentiator / Customization
/// 7. Slot #5B • Settings & Pro Overview
public enum StandardScreenshotPreset: String, CaseIterable, Identifiable, ScreenshotPresetProvider {
    case slot1Benefit = "1"
    case slot2Feature = "2"
    case slot3SecondFeature = "3"
    case slot4Result = "4"
    case slot4Celebration = "4b"
    case slot5Customization = "5"
    case slot5Settings = "5b"

    public var id: String { rawValue }

    public var slotLabel: String {
        switch self {
        case .slot1Benefit: return "Slot #1 • Main Benefit"
        case .slot2Feature: return "Slot #2 • Top Feature"
        case .slot3SecondFeature: return "Slot #3 • Second Feature"
        case .slot4Result: return "Slot #4A • Realistic Result"
        case .slot4Celebration: return "Slot #4B • Celebration / Modal"
        case .slot5Customization: return "Slot #5A • Differentiator"
        case .slot5Settings: return "Slot #5B • Settings & Pro Overview"
        }
    }

    public var title: String {
        switch self {
        case .slot1Benefit: return "Main Benefit"
        case .slot2Feature: return "Top Feature"
        case .slot3SecondFeature: return "Secondary Feature"
        case .slot4Result: return "Realistic Result / Progress"
        case .slot4Celebration: return "Milestone / Celebration Modal"
        case .slot5Customization: return "Customization / Goal Setting"
        case .slot5Settings: return "Settings & Pro Overview"
        }
    }

    public var suggestedFilename: String {
        switch self {
        case .slot1Benefit: return "01 - Main Benefit"
        case .slot2Feature: return "02 - Primary Feature"
        case .slot3SecondFeature: return "03 - Secondary Feature"
        case .slot4Result: return "04A - Consistency Calendar"
        case .slot4Celebration: return "04B - Milestone Celebration"
        case .slot5Customization: return "05A - Customization Differentiator"
        case .slot5Settings: return "05B - Settings and Pro Overview"
        }
    }

    public var systemImage: String {
        switch self {
        case .slot1Benefit: return "star.fill"
        case .slot2Feature: return "chart.bar.xaxis"
        case .slot3SecondFeature: return "list.bullet.rectangle.portrait"
        case .slot4Result: return "calendar"
        case .slot4Celebration: return "trophy.fill"
        case .slot5Customization: return "slider.horizontal.3"
        case .slot5Settings: return "gearshape.fill"
        }
    }

    public var targetTabIndex: Int? {
        switch self {
        case .slot1Benefit: return 0
        case .slot2Feature: return 2
        case .slot3SecondFeature: return 1
        case .slot4Result, .slot4Celebration: return 2
        case .slot5Customization, .slot5Settings: return 3
        }
    }

    public static func from(token: String) -> StandardScreenshotPreset? {
        let normalized = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "1", "benefit", "main":
            return .slot1Benefit
        case "2", "feature", "top":
            return .slot2Feature
        case "3", "secondary", "notes", "history":
            return .slot3SecondFeature
        case "4", "4a", "result", "calendar", "stats":
            return .slot4Result
        case "4b", "celebration", "milestone", "modal":
            return .slot4Celebration
        case "5", "5a", "custom", "goals":
            return .slot5Customization
        case "5b", "settings", "pro":
            return .slot5Settings
        default:
            return StandardScreenshotPreset.allCases.first { $0.rawValue == normalized }
        }
    }
}
