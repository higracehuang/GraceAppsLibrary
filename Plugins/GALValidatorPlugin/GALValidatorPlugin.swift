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
        validateSwiftSources(swiftFiles, projectRoot: nil, allInputFiles: swiftFiles, targetName: sourceTarget.name)
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
        validateSwiftSources(swiftFiles, projectRoot: projectRoot, allInputFiles: allFiles, targetName: target.displayName)
        return []
    }
}
#endif

// MARK: - Validation Pipeline

private func validateSwiftSources(
    _ swiftFiles: [URL],
    projectRoot: URL?,
    allInputFiles: [URL],
    targetName: String
) {
    validateReleaseNotes(in: swiftFiles)
    validateLegacyAPIBypasses(in: swiftFiles, targetName: targetName)
    validateCloudKitEntitlements(in: swiftFiles, allInputFiles: allInputFiles, projectRoot: projectRoot)
    validateAdMobPlist(in: swiftFiles, allInputFiles: allInputFiles, projectRoot: projectRoot)
    validateRequiredSettingsSections(in: swiftFiles, targetName: targetName)
    validateUXOrchestration(in: swiftFiles, targetName: targetName)
    validateLoggerUsage(in: swiftFiles, targetName: targetName)

    if let projectRoot = projectRoot {
        validateUXMoments(in: projectRoot)
        validateFastlaneIAPs(in: swiftFiles, projectRoot: projectRoot)
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

private func validateLegacyAPIBypasses(in swiftFiles: [URL], targetName: String) {
    let rules: [(needle: String, message: String)] = [
        ("Purchases.configure(", "Use UniversalPurchaseCoordinator.shared.configure(...) instead of Purchases.configure(...)."),
        ("Purchases.shared", "Use UniversalPurchaseCoordinator.shared instead of Purchases.shared."),
        ("PurchasesDelegate", "Use UniversalPurchaseCoordinator.shared instead of implementing PurchasesDelegate."),
        ("PaywallView(", "Use .universalPaywall(...) or UniversalPaywallPresenter instead of PaywallView(...) directly."),
        ("CustomerCenterView(", "Use UniversalSubscriptionSection or UniversalDebugMenu instead of CustomerCenterView(...) directly."),
        ("SKStoreReviewController.requestReview", "Use UXFlowOrchestrator.shared.requestAction(.ratingPrompt(...)) instead of SKStoreReviewController.requestReview."),
        ("@Environment(\\.requestReview)", "Use UXFlowOrchestrator.shared.requestAction(.ratingPrompt(...)) instead of @Environment(\\.requestReview)."),
        ("InterstitialAd.load(", "Use UniversalAdCoordinator.shared from GraceAppsLibraryAdMob instead of InterstitialAd.load(...)."),
        ("RateAppLinkView(", "Use AboutAppSectionView(appStoreId:) instead of RateAppLinkView(...) directly."),
        ("FeedbackToGraceNavigationView(", "Use AboutAppSectionView(appStoreId:) instead of FeedbackToGraceNavigationView(...) directly."),
        ("setPrecondition(actionId: .interstitialAd", "Remove manual .interstitialAd precondition; UniversalPurchaseCoordinator.shared.configure(...) wires it automatically."),
        ("setPrecondition(actionId: \"interstitial_ad\"", "Remove manual \"interstitial_ad\" precondition; UniversalPurchaseCoordinator.shared.configure(...) wires it automatically.")
    ]

    let isWatchTarget = targetName.localizedCaseInsensitiveContains("watch") || swiftFiles.contains { url in
        (try? String(contentsOf: url, encoding: .utf8))?.contains("import WatchKit") == true
    }

    var hasPurchaseCoordinatorConfigure = false
    var firstRevenueCatFile: URL? = nil
    var hasAdCoordinatorConfigure = false
    var firstAdMobFile: URL? = nil
    var hasScopedUXFlow = false
    var firstUXFlowCallerFile: URL? = nil

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
            if !isWatchTarget, (trimmed == "import RevenueCat" || trimmed == "import RevenueCatUI") {
                Diagnostics.error("\(fileURL.path):\(index + 1): Remove direct '\(trimmed)'; use GraceAppsLibraryRevenueCat instead.")
            }
        }

        let stripped = stripComments(from: contents)
        if stripped.contains("UniversalPurchaseCoordinator.shared.configure(") {
            hasPurchaseCoordinatorConfigure = true
        }
        if firstRevenueCatFile == nil,
           stripped.contains("import GraceAppsLibraryRevenueCat") || stripped.contains("UniversalSubscriptionSection(") {
            firstRevenueCatFile = fileURL
        }
        if stripped.contains("UniversalAdCoordinator.shared.configure(") {
            hasAdCoordinatorConfigure = true
        }
        if firstAdMobFile == nil, stripped.contains("import GraceAppsLibraryAdMob") {
            firstAdMobFile = fileURL
        }
        if stripped.contains(".scopedUXFlow(") {
            hasScopedUXFlow = true
        }
        if firstUXFlowCallerFile == nil,
           stripped.contains("UXFlowOrchestrator.shared.requestAction(") ||
           stripped.contains("UXFlowOrchestrator.shared.requestActions(") ||
           stripped.contains("UniversalPaywallPresenter.present(") {
            firstUXFlowCallerFile = fileURL
        }
        if !isWatchTarget,
           stripped.range(of: #"ReleaseNotesManager\.shared\.configure\s*\([^)]*paywallAction\s*:"#, options: .regularExpression) != nil {
            Diagnostics.error(
                "\(fileURL.path):1: Use ReleaseNotesManager.shared.configureWithPaywall(...) instead of passing paywallAction: to ReleaseNotesManager.shared.configure(...)."
            )
        }
        if stripped.range(of: #"AboutAppSectionView\s*\([^)]*(releaseNotes|isPaidUser|tierName|paywallAction)\s*:"#, options: .regularExpression) != nil {
            Diagnostics.error(
                "\(fileURL.path):1: Omit releaseNotes/isPaidUser/tierName/paywallAction in AboutAppSectionView(...); it reads ReleaseNotesManager.shared configuration automatically."
            )
        }
    }

    if let targetFile = firstRevenueCatFile, !hasPurchaseCoordinatorConfigure {
        Diagnostics.error(
            "\(targetFile.path):1: GraceAppsLibraryRevenueCat / UniversalSubscriptionSection is used, but UniversalPurchaseCoordinator.shared.configure(...) is not called at launch."
        )
    }

    if let targetFile = firstAdMobFile, !hasAdCoordinatorConfigure {
        Diagnostics.error(
            "\(targetFile.path):1: GraceAppsLibraryAdMob is used, but UniversalAdCoordinator.shared.configure(...) is not called at launch."
        )
    }

    if let callerFile = firstUXFlowCallerFile, !hasScopedUXFlow {
        Diagnostics.error(
            "\(callerFile.path):1: UXFlowOrchestrator / UniversalPaywallPresenter is used, but .scopedUXFlow() is not mounted on a root view."
        )
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

// MARK: - 6. Fastlane IAP Configs

private func validateFastlaneIAPs(in swiftFiles: [URL], projectRoot: URL) {
    var firstPurchaseCoordinatorFile: URL?
    for fileURL in swiftFiles {
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
        let stripped = stripComments(from: contents)
        if stripped.contains("UniversalPurchaseCoordinator") {
            firstPurchaseCoordinatorFile = fileURL
            break
        }
    }
    guard let triggerFile = firstPurchaseCoordinatorFile else { return }

    let iapsDir = projectRoot.appendingPathComponent("fastlane/iaps")
    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: iapsDir.path, isDirectory: &isDir), isDir.boolValue else {
        Diagnostics.error(
            "\(triggerFile.path):1: UniversalPurchaseCoordinator is used, but fastlane/iaps/ directory is missing at \(iapsDir.path). Add fastlane/iaps/<product_id>.json configs for update_iap_names."
        )
        return
    }

    let entries = (try? FileManager.default.contentsOfDirectory(at: iapsDir, includingPropertiesForKeys: nil)) ?? []
    let jsonFiles = entries.filter { $0.pathExtension.lowercased() == "json" }
    if jsonFiles.isEmpty {
        Diagnostics.error(
            "\(triggerFile.path):1: UniversalPurchaseCoordinator is used, but fastlane/iaps/ contains no *.json product ID files."
        )
    }
}

// MARK: - 7. Required Settings Sections (iOS App Targets Only)

private func validateRequiredSettingsSections(in swiftFiles: [URL], targetName: String) {
    if targetName.localizedCaseInsensitiveContains("watch") {
        return
    }
    let isWatchTarget = swiftFiles.contains { url in
        (try? String(contentsOf: url, encoding: .utf8))?.contains("import WatchKit") == true
    }
    if isWatchTarget {
        return
    }

    var hasAboutApp = false
    var hasLegal = false
    var hasAboutDeveloper = false
    var usesRevenueCat = false
    var hasUniversalDebug = false
    var hasCoreDebug = false

    for fileURL in swiftFiles {
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
        let stripped = stripComments(from: contents)
        if stripped.contains("AboutAppSectionView(") { hasAboutApp = true }
        if stripped.contains("LegalSectionView(") { hasLegal = true }
        if stripped.contains("AboutDeveloperSectionView(") { hasAboutDeveloper = true }
        if stripped.contains("import GraceAppsLibraryRevenueCat") || stripped.contains("UniversalPurchaseCoordinator") {
            usesRevenueCat = true
        }
        if stripped.contains("UniversalDeveloperSection(") ||
           stripped.contains("UniversalDebugLink(") ||
           stripped.contains("UniversalDebugMenu(") {
            hasUniversalDebug = true
        }
        if stripped.contains("DebugNavigationView(") || stripped.contains("DebugMenuView(") {
            hasCoreDebug = true
        }
    }

    if !hasAboutApp {
        Diagnostics.error("Missing AboutAppSectionView(...) in iOS app target '\(targetName)'. Add AboutAppSectionView(appStoreId:) to Settings.")
    }
    if !hasLegal {
        Diagnostics.error("Missing LegalSectionView(...) in iOS app target '\(targetName)'. Add LegalSectionView(privacyPolicyURL:) to Settings.")
    }
    if !hasAboutDeveloper {
        Diagnostics.error("Missing AboutDeveloperSectionView(...) in iOS app target '\(targetName)'. Add AboutDeveloperSectionView(excludingAppId:) to Settings.")
    }
    if usesRevenueCat && !hasUniversalDebug {
        Diagnostics.error("Missing UniversalDeveloperSection(...) / UniversalDebugLink(...) in iOS app target '\(targetName)'. Add GAL's debug menu under #if DEBUG in Settings.")
    } else if !usesRevenueCat && !hasUniversalDebug && !hasCoreDebug {
        Diagnostics.error("Missing DebugNavigationView(...) / DebugMenuView(...) in iOS app target '\(targetName)'. Add GAL's debug menu under #if DEBUG in Settings.")
    }
}

// MARK: - 7b. UX Orchestration Enforcement (iOS App Targets Only)

private func validateUXOrchestration(in swiftFiles: [URL], targetName: String) {
    if targetName.localizedCaseInsensitiveContains("watch") {
        return
    }
    let isWatchTarget = swiftFiles.contains { url in
        (try? String(contentsOf: url, encoding: .utf8))?.contains("import WatchKit") == true
    }
    if isWatchTarget {
        return
    }

    var hasScopedUXFlow = false
    var hasOrchestratorAction = false

    for fileURL in swiftFiles {
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
        let stripped = stripComments(from: contents)
        if stripped.contains(".scopedUXFlow(") {
            hasScopedUXFlow = true
        }
        if stripped.contains("UXFlowOrchestrator.shared.requestAction(") ||
           stripped.contains("UXFlowOrchestrator.shared.requestActions(") {
            hasOrchestratorAction = true
        }
    }

    if !hasScopedUXFlow {
        Diagnostics.error("Missing .scopedUXFlow() in iOS app target '\(targetName)'. Mount .scopedUXFlow() on a root view.")
    }
    if !hasOrchestratorAction {
        Diagnostics.error("Missing UXFlowOrchestrator.shared.requestAction(...) / requestActions(...) in iOS app target '\(targetName)'.")
    }
}

// MARK: - 8. GraceLogger Enforcement (iOS App Targets Only)

private func validateLoggerUsage(in swiftFiles: [URL], targetName: String) {
    if targetName.localizedCaseInsensitiveContains("watch") {
        return
    }
    let isWatchTarget = swiftFiles.contains { url in
        (try? String(contentsOf: url, encoding: .utf8))?.contains("import WatchKit") == true
    }
    if isWatchTarget {
        return
    }

    let customLoggerPattern = #"(?:^|\n)[ \t]*(?:(?:public|private|internal|fileprivate|final)[ \t]+)*(?:class|struct|enum)[ \t]+(?!GraceLogger\b)[A-Za-z0-9_]*Logger\b"#

    for fileURL in swiftFiles {
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
        let stripped = stripComments(from: contents)

        // Allow target-safe GraceLogger bridges guarded for non-main-app targets (e.g. watch/widget).
        if stripped.contains("enum GraceLogger") {
            continue
        }

        if stripped.range(of: customLoggerPattern, options: .regularExpression) != nil {
            Diagnostics.error(
                "\(fileURL.path):1: Custom Logger type is disallowed in iOS app targets. Use GraceLogger from GraceAppsLibrary instead."
            )
        }

        if stripped.contains("import OSLog") || stripped.contains("os.Logger(") || stripped.contains("Logger(subsystem:") {
            Diagnostics.error(
                "\(fileURL.path):1: Direct OSLog / os.Logger usage is disallowed in iOS app targets. Use GraceLogger from GraceAppsLibrary instead."
            )
        }
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
