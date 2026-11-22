import Foundation
import PackagePlugin

@main
struct ReleaseNotesValidatorPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        guard let sourceTarget = target as? SourceModuleTarget else {
            return []
        }
        let swiftFiles = sourceTarget.sourceFiles(withSuffix: "swift").map(\.url)
        validateReleaseNotesFiles(swiftFiles)
        return []
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension ReleaseNotesValidatorPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        let swiftFiles = target.inputFiles
            .filter { $0.type == .source && $0.url.pathExtension == "swift" }
            .map(\.url)
        validateReleaseNotesFiles(swiftFiles)
        return []
    }
}
#endif

private func validateReleaseNotesFiles(_ swiftFiles: [URL]) {
    let maxCount = 5
    for fileURL in swiftFiles {
        let name = fileURL.lastPathComponent
        guard name.localizedCaseInsensitiveContains("ReleaseNotes") else { continue }
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }

        let count = countReleaseNoteEntries(in: contents)
        if count > maxCount {
            Diagnostics.error(
                "\(fileURL.path):1: In-app release notes has \(count) entries, exceeding the display limit of \(maxCount). Run GraceAppsLibrary/scripts/prune_release_notes.py to prune older entries."
            )
        }
    }
}

private func countReleaseNoteEntries(in contents: String) -> Int {
    var count = 0
    for line in contents.components(separatedBy: .newlines) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") || trimmed.hasPrefix("*") {
            continue
        }
        var searchRange = trimmed.startIndex..<trimmed.endIndex
        while let range = trimmed.range(of: "ReleaseNote(", range: searchRange) {
            count += 1
            searchRange = range.upperBound..<trimmed.endIndex
        }
    }
    return count
}
