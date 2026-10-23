//
//  ScreenshotPresetProvider.swift
//  GraceAppsLibrary
//
//  Created by Antigravity on 10/23/26.
//

import Foundation

/// Protocol that each app conforms to for defining its App Store screenshot presets.
///
/// Example:
/// ```swift
/// public enum AppScreenshotPreset: String, ScreenshotPresetProvider {
///     case timer = "1"
///     case dashboard = "2"
///
///     public var slotLabel: String { ... }
///     public var title: String { ... }
///     public var suggestedFilename: String { ... }
///     public var systemImage: String { ... }
/// }
/// ```
public protocol ScreenshotPresetProvider: Identifiable, CaseIterable, RawRepresentable where RawValue == String {
    var id: String { get }
    var slotLabel: String { get }
    var title: String { get }
    var suggestedFilename: String { get }
    var systemImage: String { get }
    var cliArgumentExample: String { get }

    static func from(token: String) -> Self?
}

public extension ScreenshotPresetProvider {
    var id: String { rawValue }

    var cliArgumentExample: String {
        "-SCREENSHOT_PRESET \(rawValue)"
    }

    /// Default token matching parses rawValue, or case-insensitive matching.
    static func from(token: String) -> Self? {
        let normalized = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let direct = Self(rawValue: normalized) ?? Self(rawValue: token) {
            return direct
        }
        return Self.allCases.first { preset in
            preset.rawValue.lowercased() == normalized ||
            preset.id.lowercased() == normalized ||
            preset.title.lowercased().contains(normalized) ||
            preset.suggestedFilename.lowercased().contains(normalized)
        }
    }
}
