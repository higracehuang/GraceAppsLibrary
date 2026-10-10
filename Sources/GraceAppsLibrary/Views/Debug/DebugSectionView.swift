import SwiftUI

/// A self-contained settings Section that houses `DebugNavigationView` and automatically
/// compiles to `EmptyView()` in Release builds.
///
/// Usage in SettingsView (no `#if DEBUG` needed):
/// ```swift
/// DebugSectionView(
///     unlimitedAccess: $hasPurchasedUnlimitedAccess,
///     loadOfferings: { await purchaseManager.fetchOfferingIDs() },
///     onSelectOffering: { offeringId in showPaywall(offeringId) }
/// )
/// ```
public struct DebugSectionView<CustomContent: View, OnboardingContent: View>: View {
    public let sectionHeader: LocalizedStringKey
    public let title: LocalizedStringKey
    public let systemImage: String
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
        sectionHeader: LocalizedStringKey = "Developer",
        title: LocalizedStringKey = "Debug Menu",
        systemImage: String = "ladybug",
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
        self.sectionHeader = sectionHeader
        self.title = title
        self.systemImage = systemImage
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
        #if DEBUG
        Section(header: Text(sectionHeader)) {
            DebugNavigationView(
                title: title,
                systemImage: systemImage,
                includeReviews: includeReviews,
                includeAppearance: includeAppearance,
                includeResetOverrides: includeResetOverrides,
                unlimitedAccess: unlimitedAccess,
                tierName: tierName,
                paywallAction: paywallAction,
                loadOfferings: loadOfferings,
                onSelectOffering: onSelectOffering,
                onboardingStorageKey: onboardingStorageKey,
                onboardingView: onboardingView,
                onResetOverrides: onResetOverrides,
                customContent: { customContent }
            )
        }
        #endif
    }
}

// MARK: - Initializer for Apps Without Onboarding

extension DebugSectionView where OnboardingContent == EmptyView {
    public init(
        sectionHeader: LocalizedStringKey = "Developer",
        title: LocalizedStringKey = "Debug Menu",
        systemImage: String = "ladybug",
        includeReviews: Bool = true,
        includeAppearance: Bool = true,
        includeResetOverrides: Bool = true,
        unlimitedAccess: Binding<Bool>? = nil,
        tierName: String = "Unlimited Access",
        paywallAction: (() -> Void)? = nil,
        loadOfferings: (() async -> [String])? = nil,
        onSelectOffering: ((String?) -> Void)? = nil,
        onResetOverrides: (() -> Void)? = nil,
        @ViewBuilder customContent: () -> CustomContent = { EmptyView() }
    ) {
        self.init(
            sectionHeader: sectionHeader,
            title: title,
            systemImage: systemImage,
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
