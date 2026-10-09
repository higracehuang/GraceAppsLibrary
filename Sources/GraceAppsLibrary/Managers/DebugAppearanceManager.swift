#if canImport(UIKit)
import UIKit

/// Manages runtime overrides of the application's user interface style (Light, Dark, or System) for debugging and testing.
@MainActor
public enum DebugAppearanceManager {
    /// The supported appearance modes for testing.
    public enum Mode: String, CaseIterable, Identifiable {
        case system = "System"
        case light = "Light"
        case dark = "Dark"

        public var id: String { rawValue }

        public var uiUserInterfaceStyle: UIUserInterfaceStyle {
            switch self {
            case .system:
                return .unspecified
            case .light:
                return .light
            case .dark:
                return .dark
            }
        }
    }

    /// Returns the currently active debug appearance mode based on the key window's override style.
    public static func currentMode() -> Mode {
        guard let window = activeWindow() else { return .system }
        switch window.overrideUserInterfaceStyle {
        case .light:
            return .light
        case .dark:
            return .dark
        default:
            return .system
        }
    }

    /// Applies the selected appearance mode to all connected window scenes and windows.
    public static func apply(mode: Mode) {
        let style = mode.uiUserInterfaceStyle
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if !scenes.isEmpty {
            for scene in scenes {
                for window in scene.windows {
                    window.overrideUserInterfaceStyle = style
                }
            }
        } else {
            for window in UIApplication.shared.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }

    private static func activeWindow() -> UIWindow? {
        if let windowScene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            return windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first
        }
        return UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? UIApplication.shared.windows.first
    }
}
#endif
