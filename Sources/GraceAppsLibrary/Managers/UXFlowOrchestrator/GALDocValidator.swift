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
    case missingUITestFile(path: String)
    case missingUITestCase(method: String, file: String)

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
        case .missingUITestFile(let path):
            return "UX Moments UI test file not found at: \(path). Every app must include a UXMomentsUITests.swift test suite."
        case .missingUITestCase(let method, let file):
            return "UI test case '\(method)' documented in UX_MOMENTS.md is missing from \(file)."
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

    /// Searches for `UXMomentsUITests.swift` starting from a given directory URL.
    public static func locateUXMomentsUITests(in directory: URL) -> URL? {
        let fileManager = FileManager.default
        let direct = directory.appendingPathComponent("UXMomentsUITests.swift")
        if fileManager.fileExists(atPath: direct.path) { return direct }

        if let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
            for case let fileURL as URL in enumerator {
                if fileURL.lastPathComponent == "UXMomentsUITests.swift" {
                    return fileURL
                }
            }
        }
        return nil
    }

    /// Extracts automated UI test method names referenced in the markdown documentation.
    /// Matches identifiers starting with `testMatrixRow` or `test` enclosed in backticks or standard code style.
    public static func extractTestCases(from documentContent: String) -> [String] {
        let pattern = #"`(test[A-Za-z0-9_]+)`"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let range = NSRange(location: 0, length: documentContent.utf16.count)
        let matches = regex.matches(in: documentContent, options: [], range: range)
        var cases: [String] = []
        for match in matches {
            if let swiftRange = Range(match.range(at: 1), in: documentContent) {
                let name = String(documentContent[swiftRange])
                if !cases.contains(name) {
                    cases.append(name)
                }
            }
        }
        return cases
    }

    /// Validates that an app's UI test suite implements the UX moments tests defined in `UX_MOMENTS.md`.
    ///
    /// - Parameters:
    ///   - docURL: Optional URL to `UX_MOMENTS.md` to extract documented test names from.
    ///   - uiTestFileURL: URL to the app's `UXMomentsUITests.swift` source file.
    ///   - requiredTestCases: Explicit test method names required to be implemented.
    /// - Throws: `GALDocValidationError` if the test file is missing or any required test method is not implemented.
    /// - Returns: `true` if all validations pass.
    @discardableResult
    public static func validateUITestCoverage(
        docURL: URL? = nil,
        uiTestFileURL: URL,
        requiredTestCases: [String] = []
    ) throws -> Bool {
        guard FileManager.default.fileExists(atPath: uiTestFileURL.path) else {
            throw GALDocValidationError.missingUITestFile(path: uiTestFileURL.path)
        }

        guard let testContent = try? String(contentsOf: uiTestFileURL, encoding: .utf8) else {
            throw GALDocValidationError.missingUITestFile(path: uiTestFileURL.path)
        }

        var expectedTests = requiredTestCases

        if let docURL = docURL, FileManager.default.fileExists(atPath: docURL.path),
           let docContent = try? String(contentsOf: docURL, encoding: .utf8) {
            let extracted = extractTestCases(from: docContent)
            for test in extracted where !expectedTests.contains(test) {
                expectedTests.append(test)
            }
        }

        for method in expectedTests {
            let functionPattern = "func \(method)"
            if !testContent.contains(functionPattern) {
                throw GALDocValidationError.missingUITestCase(method: method, file: uiTestFileURL.lastPathComponent)
            }
        }

        return true
    }

    /// Validates the existence and contents of a UX_MOMENTS markdown document against declared triggers
    /// and optionally verifies automated UI test coverage.
    ///
    /// - Parameters:
    ///   - docURL: URL to the `UX_MOMENTS.md` file.
    ///   - uiTestFileURL: Optional URL to the app's `UXMomentsUITests.swift` source file.
    ///   - adTriggers: List of string trigger raw values declared in code.
    ///   - paywallTriggers: List of string paywall trigger raw values declared in code.
    ///   - requiredSections: Required section names that must appear as markdown headers.
    /// - Throws: `GALDocValidationError` if missing file, empty contents, missing sections, undocumented triggers, or missing UI tests.
    /// - Returns: `true` if all validations pass.
    @discardableResult
    public static func validate(
        docURL: URL,
        uiTestFileURL: URL? = nil,
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

        // Optionally validate UI test coverage
        if let uiTestFileURL = uiTestFileURL {
            try validateUITestCoverage(docURL: docURL, uiTestFileURL: uiTestFileURL)
        }

        return true
    }

    /// Overload for RawRepresentable enum collections.
    @discardableResult
    public static func validate<A: RawRepresentable, P: RawRepresentable>(
        docURL: URL,
        uiTestFileURL: URL? = nil,
        adTriggers: [A] = [],
        paywallTriggers: [P] = [],
        requiredSections: [String] = defaultRequiredSections
    ) throws -> Bool where A.RawValue == String, P.RawValue == String {
        try validate(
            docURL: docURL,
            uiTestFileURL: uiTestFileURL,
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
