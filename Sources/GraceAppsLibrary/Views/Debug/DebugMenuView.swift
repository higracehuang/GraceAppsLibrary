import SwiftUI

/// A composable developer & QA debug menu containing standard controls for reviews, entitlements,
/// RevenueCat offerings, onboarding, and custom app-specific sections.
public struct DebugMenuView<CustomContent: View, OnboardingContent: View>: View {
    public let navigationTitle: LocalizedStringKey
    public let includeReviews: Bool
    public let unlimitedAccess: Binding<Bool>?
    public let tierName: String
    public let paywallAction: (() -> Void)?
    public let loadOfferings: (() async -> [String])?
    public let onSelectOffering: ((String?) -> Void)?
    public let onboardingStorageKey: String
    public let onboardingView: (() -> OnboardingContent)?
    public let customContent: CustomContent

    public init(
        navigationTitle: LocalizedStringKey = "Debug Menu",
        includeReviews: Bool = true,
        unlimitedAccess: Binding<Bool>? = nil,
        tierName: String = "Unlimited Access",
        paywallAction: (() -> Void)? = nil,
        loadOfferings: (() async -> [String])? = nil,
        onSelectOffering: ((String?) -> Void)? = nil,
        onboardingStorageKey: String = OnboardingManager.defaultStorageKey,
        onboardingView: (() -> OnboardingContent)? = nil,
        @ViewBuilder customContent: () -> CustomContent = { EmptyView() }
    ) {
        self.navigationTitle = navigationTitle
        self.includeReviews = includeReviews
        self.unlimitedAccess = unlimitedAccess
        self.tierName = tierName
        self.paywallAction = paywallAction
        self.loadOfferings = loadOfferings
        self.onSelectOffering = onSelectOffering
        self.onboardingStorageKey = onboardingStorageKey
        self.onboardingView = onboardingView
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
        unlimitedAccess: Binding<Bool>? = nil,
        tierName: String = "Unlimited Access",
        paywallAction: (() -> Void)? = nil,
        loadOfferings: (() async -> [String])? = nil,
        onSelectOffering: ((String?) -> Void)? = nil,
        @ViewBuilder customContent: @escaping () -> CustomContent = { EmptyView() }
    ) {
        self.init(
            navigationTitle: navigationTitle,
            includeReviews: includeReviews,
            unlimitedAccess: unlimitedAccess,
            tierName: tierName,
            paywallAction: paywallAction,
            loadOfferings: loadOfferings,
            onSelectOffering: onSelectOffering,
            onboardingStorageKey: OnboardingManager.defaultStorageKey,
            onboardingView: nil,
            customContent: customContent
        )
    }
}
