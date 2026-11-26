import SwiftUI
import GraceAppsLibrary

extension DebugNavigationView {
    public init<Preset: ScreenshotPresetProvider>(
        title: LocalizedStringKey = "Debug Menu",
        systemImage: String = "ladybug",
        includeReviews: Bool = true,
        includeAppearance: Bool = true,
        includeReleaseNotes: Bool = true,
        releaseNotes: [ReleaseNote]? = nil,
        includeResetOverrides: Bool = true,
        entitlementOverride: Binding<DebugEntitlementOverride>? = nil,
        effectiveIsPro: Bool? = nil,
        unlimitedAccess: Binding<Bool>? = nil,
        tierName: String = "Unlimited Access",
        paywallAction: (() -> Void)? = nil,
        loadOfferings: (() async -> [String])? = nil,
        onSelectOffering: ((String?) -> Void)? = nil,
        onboardingStorageKey: String = OnboardingManager.defaultStorageKey,
        onboardingView: (() -> OnboardingContent)? = nil,
        screenshotEngine: ScreenshotEngine<Preset>,
        onApplyScreenshotPreset: ((Preset) -> Void)? = nil,
        onResetScreenshotPreset: (() -> Void)? = nil,
        onResetOverrides: (() -> Void)? = nil,
        @ViewBuilder customContent: () -> CustomContent = { EmptyView() }
    ) {
        self.init(
            title: title,
            systemImage: systemImage,
            includeReviews: includeReviews,
            includeAppearance: includeAppearance,
            includeReleaseNotes: includeReleaseNotes,
            releaseNotes: releaseNotes,
            includeResetOverrides: includeResetOverrides,
            entitlementOverride: entitlementOverride,
            effectiveIsPro: effectiveIsPro,
            unlimitedAccess: unlimitedAccess,
            tierName: tierName,
            paywallAction: paywallAction,
            loadOfferings: loadOfferings,
            onSelectOffering: onSelectOffering,
            onboardingStorageKey: onboardingStorageKey,
            onboardingView: onboardingView,
            screenshotSection: {
                AnyView(
                    DebugScreenshotSection(
                        engine: screenshotEngine,
                        onApplyPreset: onApplyScreenshotPreset,
                        onReset: onResetScreenshotPreset
                    )
                )
            },
            onResetOverrides: onResetOverrides,
            customContent: customContent
        )
    }
}

extension DebugNavigationView where OnboardingContent == EmptyView {
    public init<Preset: ScreenshotPresetProvider>(
        title: LocalizedStringKey = "Debug Menu",
        systemImage: String = "ladybug",
        includeReviews: Bool = true,
        includeAppearance: Bool = true,
        includeReleaseNotes: Bool = true,
        releaseNotes: [ReleaseNote]? = nil,
        includeResetOverrides: Bool = true,
        entitlementOverride: Binding<DebugEntitlementOverride>? = nil,
        effectiveIsPro: Bool? = nil,
        unlimitedAccess: Binding<Bool>? = nil,
        tierName: String = "Unlimited Access",
        paywallAction: (() -> Void)? = nil,
        loadOfferings: (() async -> [String])? = nil,
        onSelectOffering: ((String?) -> Void)? = nil,
        screenshotEngine: ScreenshotEngine<Preset>,
        onApplyScreenshotPreset: ((Preset) -> Void)? = nil,
        onResetScreenshotPreset: (() -> Void)? = nil,
        onResetOverrides: (() -> Void)? = nil,
        @ViewBuilder customContent: @escaping () -> CustomContent = { EmptyView() }
    ) {
        self.init(
            title: title,
            systemImage: systemImage,
            includeReviews: includeReviews,
            includeAppearance: includeAppearance,
            includeReleaseNotes: includeReleaseNotes,
            releaseNotes: releaseNotes,
            includeResetOverrides: includeResetOverrides,
            entitlementOverride: entitlementOverride,
            effectiveIsPro: effectiveIsPro,
            unlimitedAccess: unlimitedAccess,
            tierName: tierName,
            paywallAction: paywallAction,
            loadOfferings: loadOfferings,
            onSelectOffering: onSelectOffering,
            onboardingStorageKey: OnboardingManager.defaultStorageKey,
            onboardingView: nil,
            screenshotEngine: screenshotEngine,
            onApplyScreenshotPreset: onApplyScreenshotPreset,
            onResetScreenshotPreset: onResetScreenshotPreset,
            onResetOverrides: onResetOverrides,
            customContent: customContent
        )
    }
}
