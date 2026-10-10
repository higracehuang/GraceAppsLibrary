import SwiftUI

/// A ready-to-use NavigationLink row for Settings views that pushes `DebugMenuView`.
public struct DebugNavigationView<CustomContent: View, OnboardingContent: View>: View {
    public let title: LocalizedStringKey
    public let systemImage: String
    public let includeReviews: Bool
    public let includeAppearance: Bool
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
    public let onResetOverrides: (() -> Void)?
    public let customContent: CustomContent

    public init(
        title: LocalizedStringKey = "Debug Menu",
        systemImage: String = "ladybug",
        includeReviews: Bool = true,
        includeAppearance: Bool = true,
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
        onResetOverrides: (() -> Void)? = nil,
        @ViewBuilder customContent: () -> CustomContent = { EmptyView() }
    ) {
        self.title = title
        self.systemImage = systemImage
        self.includeReviews = includeReviews
        self.includeAppearance = includeAppearance
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
        self.onResetOverrides = onResetOverrides
        self.customContent = customContent()
    }

    public var body: some View {
        #if DEBUG
        NavigationLink(destination: DebugMenuView(
            navigationTitle: title,
            includeReviews: includeReviews,
            includeAppearance: includeAppearance,
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
            onResetOverrides: onResetOverrides,
            customContent: { customContent }
        )) {
            Label(title, systemImage: systemImage)
        }
        #endif
    }
}

// MARK: - Initializer for Apps Without Onboarding

extension DebugNavigationView where OnboardingContent == EmptyView {
    public init(
        title: LocalizedStringKey = "Debug Menu",
        systemImage: String = "ladybug",
        includeReviews: Bool = true,
        includeAppearance: Bool = true,
        includeResetOverrides: Bool = true,
        entitlementOverride: Binding<DebugEntitlementOverride>? = nil,
        effectiveIsPro: Bool? = nil,
        unlimitedAccess: Binding<Bool>? = nil,
        tierName: String = "Unlimited Access",
        paywallAction: (() -> Void)? = nil,
        loadOfferings: (() async -> [String])? = nil,
        onSelectOffering: ((String?) -> Void)? = nil,
        onResetOverrides: (() -> Void)? = nil,
        @ViewBuilder customContent: @escaping () -> CustomContent = { EmptyView() }
    ) {
        self.init(
            title: title,
            systemImage: systemImage,
            includeReviews: includeReviews,
            includeAppearance: includeAppearance,
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
            onResetOverrides: onResetOverrides,
            customContent: customContent
        )
    }
}
