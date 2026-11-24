import SwiftUI
import GraceAppsLibrary

extension ReleaseNotesManager {
    /// Configures release notes with RevenueCat paywall integration:
    /// automatically evaluates `UniversalPurchaseCoordinator.shared.isPro`, defaults `tierName`
    /// to `UniversalPurchaseCoordinator.shared.tierName`, and wires `paywallAction` to
    /// `UniversalPaywallPresenter.present(trigger:)`.
    @MainActor
    internal func configureWithPaywall(
        releaseNotes: [ReleaseNote],
        tierName: LocalizedStringKey? = nil,
        suppressOnFirstInstall: Bool = true,
        trigger: String = "release_notes"
    ) {
        let resolvedTierName = tierName ?? LocalizedStringKey(UniversalPurchaseCoordinator.shared.tierName)
        configure(
            releaseNotes: releaseNotes,
            isPaidUser: UniversalPurchaseCoordinator.shared.isPro,
            tierName: resolvedTierName,
            suppressOnFirstInstall: suppressOnFirstInstall,
            paywallAction: {
                Task { @MainActor in
                    UniversalPaywallPresenter.present(trigger: trigger)
                }
            }
        )
    }

    /// Configures release notes with RevenueCat paywall integration using the default `"release_notes"` trigger.
    @MainActor
    public func configureWithPaywall(
        releaseNotes: [ReleaseNote],
        tierName: LocalizedStringKey? = nil,
        suppressOnFirstInstall: Bool = true
    ) {
        configureWithPaywall(
            releaseNotes: releaseNotes,
            tierName: tierName,
            suppressOnFirstInstall: suppressOnFirstInstall,
            trigger: "release_notes"
        )
    }

    /// Generic overload for raw-representable paywall trigger enums.
    @MainActor
    public func configureWithPaywall<T: RawRepresentable>(
        releaseNotes: [ReleaseNote],
        tierName: LocalizedStringKey? = nil,
        suppressOnFirstInstall: Bool = true,
        trigger: T
    ) where T.RawValue == String {
        configureWithPaywall(
            releaseNotes: releaseNotes,
            tierName: tierName,
            suppressOnFirstInstall: suppressOnFirstInstall,
            trigger: trigger.rawValue
        )
    }
}
