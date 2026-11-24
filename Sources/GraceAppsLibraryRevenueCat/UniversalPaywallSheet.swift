//
//  UniversalPaywallSheet.swift
//  GraceAppsLibraryRevenueCat
//

import SwiftUI
import GraceAppsLibrary
import RevenueCat
import RevenueCatUI

/// Standardized RevenueCatUI PaywallView host view with automatic pacing telemetry,
/// runtime offering resolution, and orchestrator auto-dismissal.
internal struct UniversalPaywallView: View {
    let trigger: String
    let offeringIdentifier: String?
    let onPurchaseCompleted: ((CustomerInfo) -> Void)?

    @ObservedObject private var coordinator: UniversalPurchaseCoordinator = .shared
    @State private var offering: Offering? = nil

    internal init(
        trigger: String = "paywall_sheet",
        offeringIdentifier: String? = nil,
        onPurchaseCompleted: ((CustomerInfo) -> Void)? = nil
    ) {
        self.trigger = trigger
        self.offeringIdentifier = offeringIdentifier
        self.onPurchaseCompleted = onPurchaseCompleted
    }

    var body: some View {
        Group {
            if let offering = offering {
                PaywallView(offering: offering, displayCloseButton: true)
            } else {
                PaywallView(displayCloseButton: true)
            }
        }
        .accessibilityIdentifier("paywall.sheet")
        .onAppear {
            PaywallPacingEngine.shared.recordTriggerShown(trigger)
        }
        .onDisappear {
            PaywallPacingEngine.shared.recordTriggerDismissed(trigger)
            Task {
                await coordinator.refreshCustomerInfo()
                if coordinator.isPro {
                    PaywallPacingEngine.shared.recordTriggerPurchased(trigger)
                }
            }
        }
        .onPurchaseCompleted { customerInfo in
            PaywallPacingEngine.shared.recordTriggerPurchased(trigger)
            onPurchaseCompleted?(customerInfo)
            Task { @MainActor in
                UXFlowOrchestrator.shared.dismissCurrentAction()
            }
        }
        .onRestoreCompleted { customerInfo in
            if coordinator.isPro {
                Task { @MainActor in
                    UXFlowOrchestrator.shared.dismissCurrentAction()
                }
            }
        }
        .task {
            let targetIdentifier = offeringIdentifier ?? coordinator.selectedOfferingIdentifier
            if let targetIdentifier = targetIdentifier {
                let offerings = await coordinator.loadOfferings()
                self.offering = offerings.first { $0.identifier == targetIdentifier }
            }
        }
    }
}

/// Standardized modal sheet presentation for RevenueCatUI's PaywallView,
/// with integrated pacing telemetry, runtime offering resolution, and purchase callbacks.
internal struct UniversalPaywallSheet: ViewModifier {
    @Binding var isPresented: Bool
    let trigger: String
    let offeringIdentifier: String?
    let onPurchaseCompleted: ((CustomerInfo) -> Void)?

    init(
        isPresented: Binding<Bool>,
        trigger: String = "paywall_sheet",
        offeringIdentifier: String? = nil,
        onPurchaseCompleted: ((CustomerInfo) -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self.trigger = trigger
        self.offeringIdentifier = offeringIdentifier
        self.onPurchaseCompleted = onPurchaseCompleted
    }

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                UniversalPaywallView(
                    trigger: trigger,
                    offeringIdentifier: offeringIdentifier,
                    onPurchaseCompleted: onPurchaseCompleted
                )
            }
    }
}

public extension UXAction {
    /// Creates a critical-priority sheet action for RevenueCat paywalls managed by `UXFlowOrchestrator`.
    static func paywall(
        trigger: String = "paywall_sheet",
        offeringIdentifier: String? = nil,
        onPurchaseCompleted: ((CustomerInfo) -> Void)? = nil
    ) -> UXAction {
        UXAction(
            id: .paywall,
            priority: .critical,
            kind: .sheet,
            tags: [.paywall]
        ) {
            UniversalPaywallView(
                trigger: trigger,
                offeringIdentifier: offeringIdentifier,
                onPurchaseCompleted: onPurchaseCompleted
            )
        }
    }

    /// Overload for raw-representable trigger enums.
    static func paywall<T: RawRepresentable>(
        trigger: T,
        offeringIdentifier: String? = nil,
        onPurchaseCompleted: ((CustomerInfo) -> Void)? = nil
    ) -> UXAction where T.RawValue == String {
        paywall(
            trigger: trigger.rawValue,
            offeringIdentifier: offeringIdentifier,
            onPurchaseCompleted: onPurchaseCompleted
        )
    }
}

/// Global convenience presenter for launching the orchestrated RevenueCat paywall.
@MainActor
public enum UniversalPaywallPresenter {
    /// Presents the RevenueCat Paywall sheet through `UXFlowOrchestrator` if the user is not Pro.
    public static func present(
        trigger: String = "paywall_sheet",
        offeringIdentifier: String? = nil,
        onPurchaseCompleted: ((CustomerInfo) -> Void)? = nil
    ) {
        guard !UniversalPurchaseCoordinator.shared.isPro else { return }
        UXFlowOrchestrator.shared.requestAction(
            .paywall(
                trigger: trigger,
                offeringIdentifier: offeringIdentifier,
                onPurchaseCompleted: onPurchaseCompleted
            )
        )
    }

    /// Generic overload for raw-representable trigger enums.
    public static func present<T: RawRepresentable>(
        trigger: T,
        offeringIdentifier: String? = nil,
        onPurchaseCompleted: ((CustomerInfo) -> Void)? = nil
    ) where T.RawValue == String {
        present(
            trigger: trigger.rawValue,
            offeringIdentifier: offeringIdentifier,
            onPurchaseCompleted: onPurchaseCompleted
        )
    }
}

public typealias PaywallPresenter = UniversalPaywallPresenter

extension View {
    /// Presents the standardized RevenueCat Paywall sheet with automatic pacing tracking,
    /// offering resolution, and purchase callbacks.
    internal func universalPaywall(
        isPresented: Binding<Bool>,
        trigger: String = "paywall_sheet",
        offeringIdentifier: String? = nil,
        onPurchaseCompleted: ((CustomerInfo) -> Void)? = nil
    ) -> some View {
        modifier(UniversalPaywallSheet(
            isPresented: isPresented,
            trigger: trigger,
            offeringIdentifier: offeringIdentifier,
            onPurchaseCompleted: onPurchaseCompleted
        ))
    }

    /// Generic overload for strongly typed trigger enums conforming to `RawRepresentable` where `RawValue == String`.
    internal func universalPaywall<T: RawRepresentable>(
        isPresented: Binding<Bool>,
        trigger: T,
        offeringIdentifier: String? = nil,
        onPurchaseCompleted: ((CustomerInfo) -> Void)? = nil
    ) -> some View where T.RawValue == String {
        universalPaywall(
            isPresented: isPresented,
            trigger: trigger.rawValue,
            offeringIdentifier: offeringIdentifier,
            onPurchaseCompleted: onPurchaseCompleted
        )
    }
}
