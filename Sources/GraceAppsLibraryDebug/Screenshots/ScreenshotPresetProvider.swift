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
    var targetTabIndex: Int? { get }
    var aliases: [String] { get }
    var requiresFreeTier: Bool { get }

    static func from(token: String) -> Self?
}

public extension ScreenshotPresetProvider {
    var id: String { rawValue }
    var targetTabIndex: Int? { nil }
    var aliases: [String] { [] }
    var requiresFreeTier: Bool { false }

    var cliArgumentExample: String {
        "-SCREENSHOT_PRESET \(rawValue)"
    }

    /// Resolves a preset token with collision-free 3-tier priority:
    /// 1. Exact `rawValue` / `id` match
    /// 2. Exact `aliases` match (trimmed, case-insensitive)
    /// 3. Case-insensitive substring fallback on `title` / `suggestedFilename`
    static func from(token: String) -> Self? {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.lowercased()
        guard !normalized.isEmpty else { return nil }

        // Tier 1: Exact rawValue / id match
        if let direct = Self(rawValue: trimmed) ?? Self(rawValue: normalized) {
            return direct
        }
        if let exactRawOrId = Self.allCases.first(where: { $0.rawValue.lowercased() == normalized }) ??
            Self.allCases.first(where: { $0.id.lowercased() == normalized }) {
            return exactRawOrId
        }

        // Tier 2: Exact alias match
        if let aliasMatch = Self.allCases.first(where: { preset in
            preset.aliases.contains {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
            }
        }) {
            return aliasMatch
        }

        // Tier 3: Substring fallback on title or suggestedFilename
        return Self.allCases.first { preset in
            preset.title.lowercased().contains(normalized) ||
            preset.suggestedFilename.lowercased().contains(normalized)
        }
    }

    /// Parses `-SCREENSHOT_PRESET`, `-screenshotPreset`, or `SCREENSHOT_PRESET` from launch arguments/environment.
    /// Always returns `nil` in Release builds (`DEBUG` unset).
    static func fromLaunchEnvironment(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Self? {
        #if DEBUG
        var rawToken: String?
        if let idx = arguments.firstIndex(where: { $0 == "-SCREENSHOT_PRESET" || $0 == "-screenshotPreset" }),
           idx + 1 < arguments.count {
            rawToken = arguments[idx + 1]
        } else if let envVal = environment["SCREENSHOT_PRESET"] {
            rawToken = envVal
        }

        guard let token = rawToken else { return nil }
        return from(token: token)
        #else
        return nil
        #endif
    }
}
