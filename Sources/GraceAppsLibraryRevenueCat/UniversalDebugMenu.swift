import SwiftUI
import GraceAppsLibrary

/// Standard developer and QA debug screen for Grace Apps.
/// Assembles turnkey sections for RevenueCat entitlements & 3-way override,
/// review prompt pacing, ad pacing diagnostics, appearance, onboarding, and debug reset.
public struct UniversalDebugMenu<CustomContent: View, OnboardingContent: View>: View {
    public let navigationTitle: String
    public let onboardingStorageKey: String
    public let onboardingView: (() -> OnboardingContent)?
    public let onReset: (() -> Void)?
    public let customContent: CustomContent

    @ObservedObject private var purchaseCoordinator = UniversalPurchaseCoordinator.shared
    @State private var sessionAdCount: Int = AdPacingEngine.shared.sessionAdCount

    public init(
        navigationTitle: String = "Debug Menu",
        onboardingStorageKey: String = OnboardingManager.defaultStorageKey,
        onboardingView: (() -> OnboardingContent)? = nil,
        onReset: (() -> Void)? = nil,
        @ViewBuilder customContent: () -> CustomContent
    ) {
        self.navigationTitle = navigationTitle
        self.onboardingStorageKey = onboardingStorageKey
        self.onboardingView = onboardingView
        self.onReset = onReset
        self.customContent = customContent()
    }

    public var body: some View {
        Form {
            // MARK: - 1. Entitlements & Paywall (3-Way Override + Offerings Tester)
            DebugRevenueCatSection(
                title: "Entitlements & Paywall",
                showOfferingsTester: true,
                showDiagnostics: true
            )

            // MARK: - 2. App Reviews & Prompts
            DebugReviewPromptSection()

            // MARK: - 3. Appearance (Light / Dark Mode)
            DebugAppearanceSection()

            // MARK: - 4. Onboarding Preview (if provided)
            if let onboardingView = onboardingView {
                DebugOnboardingSection(
                    onboardingStorageKey: onboardingStorageKey,
                    onboardingView: onboardingView
                )
            }

            // MARK: - 5. Ad & Paywall Pacing Diagnostics
            pacingDiagnosticsSection

            // MARK: - 6. Custom App-Specific Tools
            customContent

            // MARK: - 7. Reset All Overrides
            DebugResetSection(
                entitlementOverride: $purchaseCoordinator.debugOverride,
                onReset: {
                    purchaseCoordinator.debugOverride = .automatic
                    AdPacingEngine.shared.resetSession()
                    sessionAdCount = AdPacingEngine.shared.sessionAdCount
                    onReset?()
                }
            )
        }
        .navigationTitle(Text(verbatim: navigationTitle))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var pacingDiagnosticsSection: some View {
        Section(
            header: Text(verbatim: "Ad & Paywall Pacing"),
            footer: Text(verbatim: "Monitors session impression counts and pacing cooldowns enforced by GraceAppsLibrary.")
        ) {
            HStack {
                Text(verbatim: "Session Ad Impressions")
                Spacer()
                Text(verbatim: "\(sessionAdCount) / \(AdPacingEngine.shared.config.maxPerSession)")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text(verbatim: "Ad Safety Debounce")
                Spacer()
                Text(verbatim: "\(Int(AdPacingEngine.shared.config.safetyDebounce))s")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text(verbatim: "Trigger Cooldown")
                Spacer()
                Text(verbatim: "\(Int(AdPacingEngine.shared.config.triggerCooldown))s")
                    .foregroundColor(.secondary)
            }

            Button {
                AdPacingEngine.shared.resetSession()
                sessionAdCount = AdPacingEngine.shared.sessionAdCount
            } label: {
                Label("Reset Ad Pacing & Session", systemImage: "arrow.counterclockwise")
            }

            let paywallStats = PaywallPacingEngine.shared.getTriggerStats(for: "debug_paywall_sheet")
            HStack {
                Text(verbatim: "Debug Paywall (Shown/Dismissed/Bought)")
                Spacer()
                Text(verbatim: "\(paywallStats.shown) / \(paywallStats.dismissed) / \(paywallStats.purchased)")
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            sessionAdCount = AdPacingEngine.shared.sessionAdCount
        }
    }
}

extension UniversalDebugMenu where CustomContent == EmptyView {
    public init(
        navigationTitle: String = "Debug Menu",
        onboardingStorageKey: String = OnboardingManager.defaultStorageKey,
        onboardingView: (() -> OnboardingContent)? = nil,
        onReset: (() -> Void)? = nil
    ) {
        self.init(
            navigationTitle: navigationTitle,
            onboardingStorageKey: onboardingStorageKey,
            onboardingView: onboardingView,
            onReset: onReset,
            customContent: { EmptyView() }
        )
    }
}

extension UniversalDebugMenu where CustomContent == EmptyView, OnboardingContent == EmptyView {
    public init(
        navigationTitle: String = "Debug Menu",
        onReset: (() -> Void)? = nil
    ) {
        self.init(
            navigationTitle: navigationTitle,
            onboardingStorageKey: OnboardingManager.defaultStorageKey,
            onboardingView: nil,
            onReset: onReset,
            customContent: { EmptyView() }
        )
    }
}
