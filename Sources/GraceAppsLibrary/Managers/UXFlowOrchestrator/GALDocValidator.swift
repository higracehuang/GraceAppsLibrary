//
//  GALDocValidator.swift
//  GraceAppsLibrary
//
//  Created by Grace Huang on 11/17/26.
//

import Foundation

/// Errors thrown when validating an app's UX_MOMENTS documentation catalog.
public enum GALDocValidationError: LocalizedError, Equatable {
    case fileNotFound(path: String)
    case fileEmpty(path: String)
    case missingSection(name: String)
    case missingAdTrigger(trigger: String)
    case missingPaywallTrigger(trigger: String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "UX_MOMENTS document not found at: \(path). Every app must include a UX_MOMENTS.md catalog."
        case .fileEmpty(let path):
            return "UX_MOMENTS document at \(path) is empty."
        case .missingSection(let name):
            return "UX_MOMENTS document is missing required section: '\(name)'."
        case .missingAdTrigger(let trigger):
            return "Ad trigger '\(trigger)' is defined in code but missing from the UX_MOMENTS.md catalog/matrix."
        case .missingPaywallTrigger(let trigger):
            return "Paywall trigger '\(trigger)' is defined in code but missing from the UX_MOMENTS.md catalog/matrix."
        }
    }
}

/// Automated validator for auditing `UX_MOMENTS.md` action matrices against code implementations.
public enum GALDocValidator {
    
    /// Required sections that must be present in every app's `UX_MOMENTS.md`.
    public static let defaultRequiredSections = [
        "Architectural Overview",
        "Paywall",
        "Rating",
        "Ad",
        "Matrix",
        "QA"
    ]

    /// Searches for `UX_MOMENTS.md` in standard project locations starting from a given directory URL.
    /// Checks: root directory, `AppInfo/`, and `ProjectInfo/`.
    public static func locateUXMoments(in directory: URL) -> URL? {
        let candidates = [
            directory.appendingPathComponent("UX_MOMENTS.md"),
            directory.appendingPathComponent("AppInfo/UX_MOMENTS.md"),
            directory.appendingPathComponent("ProjectInfo/UX_MOMENTS.md")
        ]
        return candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) })
    }

    /// Validates the existence and contents of a UX_MOMENTS markdown document against declared triggers.
    ///
    /// - Parameters:
    ///   - docURL: URL to the `UX_MOMENTS.md` file.
    ///   - adTriggers: List of string trigger raw values declared in code (e.g. `FastingAdTrigger.allCases.map(\.rawValue)`).
    ///   - paywallTriggers: List of string paywall trigger raw values declared in code.
    ///   - requiredSections: Required section names that must appear as markdown headers.
    /// - Throws: `GALDocValidationError` if missing file, empty contents, missing sections, or undocumented triggers.
    /// - Returns: `true` if all validations pass.
    @discardableResult
    public static func validate(
        docURL: URL,
        adTriggers: [String] = [],
        paywallTriggers: [String] = [],
        requiredSections: [String] = defaultRequiredSections
    ) throws -> Bool {
        guard FileManager.default.fileExists(atPath: docURL.path) else {
            throw GALDocValidationError.fileNotFound(path: docURL.path)
        }

        guard let content = try? String(contentsOf: docURL, encoding: .utf8) else {
            throw GALDocValidationError.fileNotFound(path: docURL.path)
        }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw GALDocValidationError.fileEmpty(path: docURL.path)
        }

        // Validate required sections
        let lowerContent = content.lowercased()
        for section in requiredSections {
            if !lowerContent.contains(section.lowercased()) {
                throw GALDocValidationError.missingSection(name: section)
            }
        }

        // Validate ad triggers (checks if trigger key or snake_case / camelCase representation is documented)
        for trigger in adTriggers {
            guard trigger != "none" else { continue }
            if !containsTrigger(content: content, trigger: trigger) {
                throw GALDocValidationError.missingAdTrigger(trigger: trigger)
            }
        }

        // Validate paywall triggers
        for trigger in paywallTriggers {
            guard trigger != "none" else { continue }
            if !containsTrigger(content: content, trigger: trigger) {
                throw GALDocValidationError.missingPaywallTrigger(trigger: trigger)
            }
        }

        return true
    }

    /// Overload for RawRepresentable enum collections.
    @discardableResult
    public static func validate<A: RawRepresentable, P: RawRepresentable>(
        docURL: URL,
        adTriggers: [A] = [],
        paywallTriggers: [P] = [],
        requiredSections: [String] = defaultRequiredSections
    ) throws -> Bool where A.RawValue == String, P.RawValue == String {
        try validate(
            docURL: docURL,
            adTriggers: adTriggers.map(\.rawValue),
            paywallTriggers: paywallTriggers.map(\.rawValue),
            requiredSections: requiredSections
        )
    }

    private static func containsTrigger(content: String, trigger: String) -> Bool {
        if content.contains(trigger) { return true }
        
        // Check snake_case variant (e.g. "fastCompleted" -> "fast_completed")
        let snake = toSnakeCase(trigger)
        if content.contains(snake) { return true }

        // Check camelCase variant (e.g. "fast_completed" -> "fastCompleted")
        let camel = toCamelCase(trigger)
        if content.contains(camel) { return true }

        return false
    }

    private static func toSnakeCase(_ string: String) -> String {
        let pattern = "([a-z0-9])([A-Z])"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: string.utf16.count)
        return regex?.stringByReplacingMatches(in: string, options: [], range: range, withTemplate: "$1_$2").lowercased() ?? string.lowercased()
    }

    private static func toCamelCase(_ string: String) -> String {
        let parts = string.split(separator: "_")
        guard let first = parts.first else { return string }
        return String(first).lowercased() + parts.dropFirst().map { $0.capitalized }.joined()
    }
}
