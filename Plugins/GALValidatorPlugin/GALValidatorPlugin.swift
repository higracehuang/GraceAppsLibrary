import Foundation
import PackagePlugin

@main
struct GALValidatorPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        guard let sourceTarget = target as? SourceModuleTarget else {
            return []
        }
        let swiftFiles = sourceTarget.sourceFiles(withSuffix: "swift")
            .map { URL(fileURLWithPath: $0.path.string) }
        validateSwiftSources(swiftFiles, projectRoot: nil, allInputFiles: swiftFiles)
        return []
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension GALValidatorPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        let allFiles = target.inputFiles.map { URL(fileURLWithPath: $0.path.string) }
        let swiftFiles = target.inputFiles
            .filter { $0.type == .source && $0.path.extension == "swift" }
            .map { URL(fileURLWithPath: $0.path.string) }
        let projectRoot = URL(fileURLWithPath: context.xcodeProject.directory.string)
        validateSwiftSources(swiftFiles, projectRoot: projectRoot, allInputFiles: allFiles)
        return []
    }
}
#endif

// MARK: - Validation Pipeline

private func validateSwiftSources(
    _ swiftFiles: [URL],
    projectRoot: URL?,
    allInputFiles: [URL]
) {
    validateReleaseNotes(in: swiftFiles)
    validateLegacyAPIBypasses(in: swiftFiles)
    validateCloudKitEntitlements(in: swiftFiles, allInputFiles: allInputFiles, projectRoot: projectRoot)
    validateAdMobPlist(in: swiftFiles, allInputFiles: allInputFiles, projectRoot: projectRoot)

    if let projectRoot = projectRoot {
        validateUXMoments(in: projectRoot)
    }
}

// MARK: - 1. Release Notes

private func validateReleaseNotes(in swiftFiles: [URL]) {
    let maxCount = 5
    var releaseNotesFiles: [URL] = []
    var hasConfigureCall = false

    for fileURL in swiftFiles {
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
        let stripped = stripComments(from: contents)

        if stripped.contains("ReleaseNotesManager.shared.configure(") ||
           stripped.contains("ReleaseNotesManager.shared.configureWithPaywall(") {
            hasConfigureCall = true
        }

        guard fileURL.lastPathComponent.localizedCaseInsensitiveContains("ReleaseNotes") else { continue }
        let count = countOccurrences(of: "ReleaseNote(", in: stripped)
        if count > 0 {
            releaseNotesFiles.append(fileURL)
        }
        if count > maxCount {
            Diagnostics.error(
                "\(fileURL.path):1: In-app release notes has \(count) entries, exceeding the display limit of \(maxCount). Run GraceAppsLibrary/scripts/prune_release_notes.py to prune older entries."
            )
        }

        let versions = captureMatches(pattern: #"ReleaseNote\s*\(\s*version\s*:\s*"([^"]+)""#, in: stripped)
        var seen = Set<String>()
        for version in versions where !seen.insert(version).inserted {
            Diagnostics.error("\(fileURL.path):1: Duplicate ReleaseNote version '\(version)'.")
        }

        if stripped.range(of: #"notes\s*:\s*\[\s*\]"#, options: .regularExpression) != nil {
            Diagnostics.error("\(fileURL.path):1: ReleaseNote entry has an empty 'notes: []' array.")
        }
    }

    if let firstReleaseNotesFile = releaseNotesFiles.first, !hasConfigureCall {
        Diagnostics.error(
            "\(firstReleaseNotesFile.path):1: ReleaseNotes are defined, but neither ReleaseNotesManager.shared.configure(...) nor configureWithPaywall(...) is called at launch."
        )
    }
}

// MARK: - 2. Legacy / Bypassed GAL API Guardrails

private func validateLegacyAPIBypasses(in swiftFiles: [URL]) {
    let rules: [(needle: String, message: String)] = [
        ("Purchases.configure(", "Use UniversalPurchaseCoordinator.shared.configure(...) instead of Purchases.configure(...)."),
        ("PaywallView(", "Use .universalPaywall(...) or UniversalPaywallPresenter instead of PaywallView(...) directly."),
        ("SKStoreReviewController.requestReview", "Use UXFlowOrchestrator.shared.requestAction(.ratingPrompt(...)) instead of SKStoreReviewController.requestReview."),
        ("setPrecondition(actionId: .interstitialAd", "Remove manual .interstitialAd precondition; UniversalPurchaseCoordinator.shared.configure(...) wires it automatically."),
        ("setPrecondition(actionId: \"interstitial_ad\"", "Remove manual \"interstitial_ad\" precondition; UniversalPurchaseCoordinator.shared.configure(...) wires it automatically.")
    ]

    let usesRevenueCat = swiftFiles.contains { fileURL in
        (try? String(contentsOf: fileURL, encoding: .utf8))?.contains("import GraceAppsLibraryRevenueCat") == true
    }

    for fileURL in swiftFiles {
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
        let lines = contents.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") || trimmed.hasPrefix("*") {
                continue
            }
            for rule in rules where trimmed.contains(rule.needle) {
                Diagnostics.error("\(fileURL.path):\(index + 1): \(rule.message)")
            }
        }

        let stripped = stripComments(from: contents)
        if usesRevenueCat,
           stripped.range(of: #"ReleaseNotesManager\.shared\.configure\s*\([^)]*paywallAction\s*:"#, options: .regularExpression) != nil {
            Diagnostics.error(
                "\(fileURL.path):1: Use ReleaseNotesManager.shared.configureWithPaywall(...) instead of passing paywallAction: to ReleaseNotesManager.shared.configure(...)."
            )
        }
        if stripped.range(of: #"AboutAppSectionView\s*\([^)]*releaseNotes\s*:"#, options: .regularExpression) != nil {
            Diagnostics.error(
                "\(fileURL.path):1: Omit releaseNotes: in AboutAppSectionView(...); it reads ReleaseNotesManager.shared.configuredReleaseNotes automatically."
            )
        }
    }
}

// MARK: - 3. CloudKit Container ID vs Entitlements

private func validateCloudKitEntitlements(
    in swiftFiles: [URL],
    allInputFiles: [URL],
    projectRoot: URL?
) {
    var configuredContainers: [(file: URL, containerId: String)] = []
    for fileURL in swiftFiles {
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
        let stripped = stripComments(from: contents)
        guard stripped.contains("CloudKitSyncManager.shared.configure(") else { continue }
        let ids = captureMatches(
            pattern: #"CloudKitSyncManager\.shared\.configure\([^)]*containerIdentifier\s*:\s*"([^"]+)""#,
            in: stripped
        )
        for id in ids {
            configuredContainers.append((fileURL, id))
        }
    }
    guard !configuredContainers.isEmpty else { return }

    let entitlementFiles = findFiles(withExtension: "entitlements", in: allInputFiles, projectRoot: projectRoot)
    guard !entitlementFiles.isEmpty else { return }

    let combinedEntitlements = entitlementFiles
        .compactMap { try? String(contentsOf: $0, encoding: .utf8) }
        .joined(separator: "\n")

    for (fileURL, containerId) in configuredContainers where !combinedEntitlements.contains(containerId) {
        Diagnostics.error(
            "\(fileURL.path):1: CloudKit container '\(containerId)' configured in CloudKitSyncManager is missing from *.entitlements."
        )
    }
}

// MARK: - 4. AdMob Info.plist Check

private func validateAdMobPlist(
    in swiftFiles: [URL],
    allInputFiles: [URL],
    projectRoot: URL?
) {
    let usesAdMob = swiftFiles.contains { fileURL in
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else { return false }
        return contents.contains("import GraceAppsLibraryAdMob")
    }
    guard usesAdMob else { return }

    let plistFiles = findFiles(named: "Info.plist", in: allInputFiles, projectRoot: projectRoot)
    guard !plistFiles.isEmpty else { return }

    let hasGADAppId = plistFiles.contains { url in
        (try? String(contentsOf: url, encoding: .utf8))?.contains("GADApplicationIdentifier") == true
    }
    if !hasGADAppId {
        Diagnostics.error("Info.plist is missing 'GADApplicationIdentifier' required by GraceAppsLibraryAdMob.")
    }
}

// MARK: - 5. UX_MOMENTS.md & UXMomentsUITests.swift

private func validateUXMoments(in projectRoot: URL) {
    let candidates = [
        projectRoot.appendingPathComponent("UX_MOMENTS.md"),
        projectRoot.appendingPathComponent("AppInfo/UX_MOMENTS.md"),
        projectRoot.appendingPathComponent("ProjectInfo/UX_MOMENTS.md")
    ]
    guard let docURL = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
        Diagnostics.error("UX_MOMENTS.md not found at project root, AppInfo/, or ProjectInfo/.")
        return
    }
    guard let docContent = try? String(contentsOf: docURL, encoding: .utf8),
          !docContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        Diagnostics.error("\(docURL.path):1: UX_MOMENTS.md is empty.")
        return
    }

    let requiredSections = ["Architectural Overview", "Paywall", "Rating", "Ad", "Matrix", "QA"]
    let lowerDoc = docContent.lowercased()
    for section in requiredSections where !lowerDoc.contains(section.lowercased()) {
        Diagnostics.error("\(docURL.path):1: UX_MOMENTS.md is missing required section '\(section)'.")
    }

    let testCases = captureMatches(pattern: #"`(test[A-Za-z0-9_]+)`"#, in: docContent)
    guard !testCases.isEmpty else { return }

    if let uiTestURL = findFiles(named: "UXMomentsUITests.swift", in: [], projectRoot: projectRoot).first,
       let uiTestContent = try? String(contentsOf: uiTestURL, encoding: .utf8) {
        for testCase in testCases where !uiTestContent.contains("func \(testCase)(") {
            Diagnostics.error("\(uiTestURL.path):1: UI test '\(testCase)' documented in UX_MOMENTS.md is missing.")
        }
    } else {
        Diagnostics.error("UXMomentsUITests.swift not found in project to verify tests documented in UX_MOMENTS.md.")
    }
}

// MARK: - Helpers

private func stripComments(from source: String) -> String {
    source
        .components(separatedBy: .newlines)
        .filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("//") && !trimmed.hasPrefix("/*") && !trimmed.hasPrefix("*")
        }
        .joined(separator: "\n")
}

private func countOccurrences(of needle: String, in text: String) -> Int {
    var count = 0
    var searchRange = text.startIndex..<text.endIndex
    while let range = text.range(of: needle, range: searchRange) {
        count += 1
        searchRange = range.upperBound..<text.endIndex
    }
    return count
}

private func captureMatches(pattern: String, in text: String) -> [String] {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
    let range = NSRange(location: 0, length: text.utf16.count)
    return regex.matches(in: text, options: [], range: range).compactMap { match in
        guard match.numberOfRanges > 1,
              let swiftRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[swiftRange])
    }
}

private func findFiles(named fileName: String? = nil, withExtension ext: String? = nil, in inputFiles: [URL], projectRoot: URL?) -> [URL] {
    var results = inputFiles.filter { url in
        if let fileName = fileName, url.lastPathComponent != fileName { return false }
        if let ext = ext, url.pathExtension != ext { return false }
        return true
    }
    if results.isEmpty, let root = projectRoot,
       let enumerator = FileManager.default.enumerator(
           at: root,
           includingPropertiesForKeys: [.isRegularFileKey],
           options: [.skipsHiddenFiles, .skipsPackageDescendants]
       ) {
        for case let url as URL in enumerator {
            if url.path.contains("/.build/") || url.path.contains("/DerivedData/") { continue }
            if let fileName = fileName, url.lastPathComponent != fileName { continue }
            if let ext = ext, url.pathExtension != ext { continue }
            results.append(url)
        }
    }
    return results
}
