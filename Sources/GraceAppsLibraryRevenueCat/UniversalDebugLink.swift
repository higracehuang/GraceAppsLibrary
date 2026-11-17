import SwiftUI
import GraceAppsLibrary

/// A turnkey NavigationLink row that navigates to the standard `UniversalDebugMenu`.
/// Places an icon and title ("Grace Developer Tools") with zero configuration.
public struct UniversalDebugLink<OnboardingContent: View>: View {
    public let title: String
    public let systemImage: String
    public let onboardingStorageKey: String
    public let onboardingView: (() -> OnboardingContent)?
    public let onReset: (() -> Void)?

    public init(
        title: String = "Debug Menu",
        systemImage: String = "ladybug",
        onboardingStorageKey: String = OnboardingManager.defaultStorageKey,
        onboardingView: (() -> OnboardingContent)? = nil,
        onReset: (() -> Void)? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.onboardingStorageKey = onboardingStorageKey
        self.onboardingView = onboardingView
        self.onReset = onReset
    }

    public var body: some View {
        NavigationLink {
            UniversalDebugMenu(
                onboardingStorageKey: onboardingStorageKey,
                onboardingView: onboardingView,
                onReset: onReset
            )
        } label: {
            Label(title, systemImage: systemImage)
        }
    }
}

extension UniversalDebugLink where OnboardingContent == EmptyView {
    public init(
        title: String = "Debug Menu",
        systemImage: String = "ladybug",
        onReset: (() -> Void)? = nil
    ) {
        self.init(
            title: title,
            systemImage: systemImage,
            onboardingStorageKey: OnboardingManager.defaultStorageKey,
            onboardingView: nil,
            onReset: onReset
        )
    }
}
