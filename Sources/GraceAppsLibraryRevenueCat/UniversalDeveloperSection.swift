import SwiftUI
import GraceAppsLibrary

/// A turnkey developer section for `SettingsView` that encapsulates the standard `UniversalDebugLink`
/// and embeds `#if DEBUG` so it automatically strips itself out (evaluates to `EmptyView`) in Release builds.
///
/// Usage in SettingsView (zero custom tools):
/// ```swift
/// UniversalDeveloperSection()
/// ```
///
/// Usage with custom app tools:
/// ```swift
/// UniversalDeveloperSection {
///     NavigationLink("App Data Tools") {
///         MyAppDataToolsView()
///     }
/// }
/// ```
public struct UniversalDeveloperSection<CustomContent: View, OnboardingContent: View>: View {
    public let title: String
    public let debugLinkTitle: String
    public let debugLinkSystemImage: String
    public let onboardingStorageKey: String
    public let onboardingView: (() -> OnboardingContent)?
    public let onReset: (() -> Void)?
    public let customContent: CustomContent

    public init(
        title: String = "Developer",
        debugLinkTitle: String = "Debug Menu",
        debugLinkSystemImage: String = "ladybug",
        onboardingStorageKey: String = OnboardingManager.defaultStorageKey,
        onboardingView: (() -> OnboardingContent)? = nil,
        onReset: (() -> Void)? = nil,
        @ViewBuilder customContent: () -> CustomContent
    ) {
        self.title = title
        self.debugLinkTitle = debugLinkTitle
        self.debugLinkSystemImage = debugLinkSystemImage
        self.onboardingStorageKey = onboardingStorageKey
        self.onboardingView = onboardingView
        self.onReset = onReset
        self.customContent = customContent()
    }

    @ViewBuilder
    public var body: some View {
        #if DEBUG
        Section(header: Text(verbatim: title)) {
            UniversalDebugLink(
                title: debugLinkTitle,
                systemImage: debugLinkSystemImage,
                onboardingStorageKey: onboardingStorageKey,
                onboardingView: onboardingView,
                onReset: onReset,
                customContent: { customContent }
            )
        }
        #else
        EmptyView()
        #endif
    }
}

extension UniversalDeveloperSection where CustomContent == EmptyView, OnboardingContent == EmptyView {
    public init(
        title: String = "Developer",
        debugLinkTitle: String = "Debug Menu",
        debugLinkSystemImage: String = "ladybug",
        onReset: (() -> Void)? = nil
    ) {
        self.init(
            title: title,
            debugLinkTitle: debugLinkTitle,
            debugLinkSystemImage: debugLinkSystemImage,
            onboardingStorageKey: OnboardingManager.defaultStorageKey,
            onboardingView: nil,
            onReset: onReset,
            customContent: { EmptyView() }
        )
    }
}

extension UniversalDeveloperSection where CustomContent == EmptyView {
    public init(
        title: String = "Developer",
        debugLinkTitle: String = "Debug Menu",
        debugLinkSystemImage: String = "ladybug",
        onboardingStorageKey: String = OnboardingManager.defaultStorageKey,
        onboardingView: (() -> OnboardingContent)? = nil,
        onReset: (() -> Void)? = nil
    ) {
        self.init(
            title: title,
            debugLinkTitle: debugLinkTitle,
            debugLinkSystemImage: debugLinkSystemImage,
            onboardingStorageKey: onboardingStorageKey,
            onboardingView: onboardingView,
            onReset: onReset,
            customContent: { EmptyView() }
        )
    }
}

extension UniversalDeveloperSection where OnboardingContent == EmptyView {
    public init(
        title: String = "Developer",
        debugLinkTitle: String = "Debug Menu",
        debugLinkSystemImage: String = "ladybug",
        onReset: (() -> Void)? = nil,
        @ViewBuilder customContent: () -> CustomContent
    ) {
        self.init(
            title: title,
            debugLinkTitle: debugLinkTitle,
            debugLinkSystemImage: debugLinkSystemImage,
            onboardingStorageKey: OnboardingManager.defaultStorageKey,
            onboardingView: nil,
            onReset: onReset,
            customContent: customContent
        )
    }
}
