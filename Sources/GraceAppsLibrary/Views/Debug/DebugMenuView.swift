import SwiftUI

/// A composable developer & QA debug menu containing standard controls for reviews, entitlements,
/// RevenueCat offerings, onboarding, and custom app-specific sections.
public struct DebugMenuView<CustomContent: View, OnboardingContent: View>: View {
    public let navigationTitle: LocalizedStringKey
    public let includeReviews: Bool
    public let includeAppearance: Bool
    public let includeResetOverrides: Bool
    public let unlimitedAccess: Binding<Bool>?
    public let tierName: String
    public let paywallAction: (() -> Void)?
    public let loadOfferings: (() async -> [String])?
    public let onSelectOffering: ((String?) -> Void)?
    public let onboardingStorageKey: String
    public let onboardingView: (() -> OnboardingContent)?
    public let onResetOverrides: (() -> Void)?
    public let customContent: CustomContent

    public init(
        navigationTitle: LocalizedStringKey = "Debug Menu",
        includeReviews: Bool = true,
        includeAppearance: Bool = true,
        includeResetOverrides: Bool = true,
        unlimitedAccess: Binding<Bool>? = nil,
        tierName: String = "Unlimited Access",
        paywallAction: (() -> Void)? = nil,
        loadOfferings: (() async -> [String])? = nil,
        onSelectOffering: ((String?) -> Void)? = nil,
        onboardingStorageKey: String = OnboardingManager.defaultStorageKey,
        onboardingView: (() -> OnboardingContent)? = nil,
        onResetOverrides: (() -> Void)? = nil,
        @ViewBuilder customContent: () -> CustomContent = { EmptyView() }
    ) {
        self.navigationTitle = navigationTitle
        self.includeReviews = includeReviews
        self.includeAppearance = includeAppearance
        self.includeResetOverrides = includeResetOverrides
        self.unlimitedAccess = unlimitedAccess
        self.tierName = tierName
        self.paywallAction = paywallAction
        self.loadOfferings = loadOfferings
        self.onSelectOffering = onSelectOffering
        self.onboardingStorageKey = onboardingStorageKey
        self.onboardingView = onboardingView
        self.onResetOverrides = onResetOverrides
        self.customContent = customContent()
    }

    public var body: some View {
        Form {
            // MARK: - Entitlements & Paywall
            if let unlimitedAccess = unlimitedAccess {
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

            // MARK: - Onboarding
            if let onboardingView = onboardingView {
                DebugOnboardingSection(
                    onboardingStorageKey: onboardingStorageKey,
                    onboardingView: onboardingView
                )
            }

            // MARK: - App-Specific Custom Content
            customContent

            // MARK: - Reset All Overrides
            if includeResetOverrides {
                DebugResetSection(
                    unlimitedAccess: unlimitedAccess,
                    onReset: onResetOverrides
                )
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Convenience Initializers for Apps Without Onboarding

extension DebugMenuView where OnboardingContent == EmptyView {
    public init(
        navigationTitle: LocalizedStringKey = "Debug Menu",
        includeReviews: Bool = true,
        includeAppearance: Bool = true,
        includeResetOverrides: Bool = true,
        unlimitedAccess: Binding<Bool>? = nil,
        tierName: String = "Unlimited Access",
        paywallAction: (() -> Void)? = nil,
        loadOfferings: (() async -> [String])? = nil,
        onSelectOffering: ((String?) -> Void)? = nil,
        onResetOverrides: (() -> Void)? = nil,
        @ViewBuilder customContent: @escaping () -> CustomContent = { EmptyView() }
    ) {
        self.init(
            navigationTitle: navigationTitle,
            includeReviews: includeReviews,
            includeAppearance: includeAppearance,
            includeResetOverrides: includeResetOverrides,
            unlimitedAccess: unlimitedAccess,
            tierName: tierName,
            paywallAction: paywallAction,
            loadOfferings: loadOfferings,
            onSelectOffering: onSelectOffering,
            onboardingStorageKey: OnboardingManager.defaultStorageKey,
            onboardingView: nil,
            onResetOverrides: onResetOverrides,
            customContent: customContent
        )
    }
}
