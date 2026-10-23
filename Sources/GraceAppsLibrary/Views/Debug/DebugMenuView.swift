import SwiftUI

/// A composable developer & QA debug menu containing standard controls for reviews, entitlements,
/// RevenueCat offerings, onboarding, and custom app-specific sections.
public struct DebugMenuView<CustomContent: View, OnboardingContent: View>: View {
    public let navigationTitle: LocalizedStringKey
    public let includeReviews: Bool
    public let includeAppearance: Bool
    public let includeReleaseNotes: Bool
    public let releaseNotes: [ReleaseNote]?
    public let includeResetOverrides: Bool
    public let entitlementOverride: Binding<DebugEntitlementOverride>?
    public let effectiveIsPro: Bool?
    public let unlimitedAccess: Binding<Bool>?
    public let tierName: String
    public let paywallAction: (() -> Void)?
    public let loadOfferings: (() async -> [String])?
    public let onSelectOffering: ((String?) -> Void)?
    public let onboardingStorageKey: String
    public let onboardingView: (() -> OnboardingContent)?
    public let screenshotSection: (() -> AnyView)?
    public let onResetOverrides: (() -> Void)?
    public let customContent: CustomContent

    public init(
        navigationTitle: LocalizedStringKey = "Debug Menu",
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
        screenshotSection: (() -> AnyView)? = nil,
        onResetOverrides: (() -> Void)? = nil,
        @ViewBuilder customContent: () -> CustomContent = { EmptyView() }
    ) {
        self.navigationTitle = navigationTitle
        self.includeReviews = includeReviews
        self.includeAppearance = includeAppearance
        self.includeReleaseNotes = includeReleaseNotes
        self.releaseNotes = releaseNotes
        self.includeResetOverrides = includeResetOverrides
        self.entitlementOverride = entitlementOverride
        self.effectiveIsPro = effectiveIsPro
        self.unlimitedAccess = unlimitedAccess
        self.tierName = tierName
        self.paywallAction = paywallAction
        self.loadOfferings = loadOfferings
        self.onSelectOffering = onSelectOffering
        self.onboardingStorageKey = onboardingStorageKey
        self.onboardingView = onboardingView
        self.screenshotSection = screenshotSection
        self.onResetOverrides = onResetOverrides
        self.customContent = customContent()
    }

    public var body: some View {
        Form {
            // MARK: - Entitlements & Paywall
            if let entitlementOverride = entitlementOverride {
                DebugEntitlementsSection(
                    override: entitlementOverride,
                    effectiveIsPro: effectiveIsPro,
                    tierName: tierName,
                    paywallAction: paywallAction
                )
            } else if let unlimitedAccess = unlimitedAccess {
                DebugEntitlementsSection(
                    unlimitedAccess: unlimitedAccess,
                    tierName: tierName,
                    paywallAction: paywallAction
                )
            }

            // MARK: - RevenueCat Offerings
            if let onSelectOffering = onSelectOffering {
                DebugOfferingsSection(
                    loadOfferings: loadOfferings,
                    onSelectOffering: onSelectOffering
                )
            }

            // MARK: - Appearance (Light / Dark Mode)
            if includeAppearance {
                DebugAppearanceSection()
            }

            // MARK: - App Reviews
            if includeReviews {
                DebugReviewPromptSection()
            }

            // MARK: - Release Notes
            if includeReleaseNotes {
                DebugReleaseNotesSection(
                    releaseNotes: releaseNotes,
                    isPaidUser: effectiveIsPro ?? unlimitedAccess?.wrappedValue ?? false,
                    tierName: LocalizedStringKey(tierName),
                    paywallAction: paywallAction
                )
            }

            // MARK: - Onboarding
            if let onboardingView = onboardingView {
                DebugOnboardingSection(
                    onboardingStorageKey: onboardingStorageKey,
                    onboardingView: onboardingView
                )
            }

            // MARK: - App Store Screenshots
            if let screenshotSection = screenshotSection {
                screenshotSection()
            }

            // MARK: - App-Specific Custom Content
            customContent

            // MARK: - Reset All Overrides
            if includeResetOverrides {
                DebugResetSection(
                    entitlementOverride: entitlementOverride,
                    unlimitedAccess: unlimitedAccess,
                    onReset: onResetOverrides
                )
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
    public init<Preset: ScreenshotPresetProvider>(
        navigationTitle: LocalizedStringKey = "Debug Menu",
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
            navigationTitle: navigationTitle,
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

// MARK: - Convenience Initializers for Apps Without Onboarding

extension DebugMenuView where OnboardingContent == EmptyView {
    public init(
        navigationTitle: LocalizedStringKey = "Debug Menu",
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
        screenshotSection: (() -> AnyView)? = nil,
        onResetOverrides: (() -> Void)? = nil,
        @ViewBuilder customContent: @escaping () -> CustomContent = { EmptyView() }
    ) {
        self.init(
            navigationTitle: navigationTitle,
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
            screenshotSection: screenshotSection,
            onResetOverrides: onResetOverrides,
            customContent: customContent
        )
    }

    public init<Preset: ScreenshotPresetProvider>(
        navigationTitle: LocalizedStringKey = "Debug Menu",
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
            navigationTitle: navigationTitle,
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
