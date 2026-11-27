import Foundation

/// Cross-target launch-flag detector shared across iOS, WatchOS, and Widget targets.
/// All checks are compiled out in Release (`DEBUG` unset) and return `false`.
public enum GraceLaunchFlags {
    /// Returns `true` if screenshot capture is active based on launch arguments or environment variables.
    public static func isScreenshotCaptureActive(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        #if DEBUG
        if arguments.contains("-SCREENSHOT_PRESET") ||
            arguments.contains("-screenshotPreset") ||
            arguments.contains("-SCREENSHOT_CAPTURE") ||
            arguments.contains("-FORCE_PRO") ||
            arguments.contains("-screenshotForcePro") {
            return true
        }
        if let val = environment["SCREENSHOT_PRESET"], !val.isEmpty { return true }
        if let val = environment["IS_SCREENSHOT_ACTIVE"], !val.isEmpty { return true }
        if let val = environment["FORCE_PRO"], !val.isEmpty { return true }
        return false
        #else
        return false
        #endif
    }

    /// Returns `true` if screenshot capture or standalone mock-data launch flags
    /// (`-USE_MOCK_DATA`, `-ENABLE_MOCK_DATA`, `-ENABLE_SCREENSHOT_MOCK_DATA`) are active.
    public static func isMockDataModeActive(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        #if DEBUG
        if isScreenshotCaptureActive(arguments: arguments, environment: environment) {
            return true
        }
        let mockFlags = ["-USE_MOCK_DATA", "-ENABLE_MOCK_DATA", "-ENABLE_SCREENSHOT_MOCK_DATA"]
        if arguments.contains(where: { mockFlags.contains($0) }) {
            return true
        }
        let mockEnvKeys = ["USE_MOCK_DATA", "ENABLE_MOCK_DATA", "ENABLE_SCREENSHOT_MOCK_DATA"]
        return mockEnvKeys.contains { key in
            guard let raw = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                  !raw.isEmpty else {
                return false
            }
            return raw != "0" && raw != "false" && raw != "no"
        }
        #else
        return false
        #endif
    }
}
