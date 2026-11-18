//
//  UniversalPaywallSheet.swift
//  GraceAppsLibraryRevenueCat
//

import SwiftUI
import GraceAppsLibrary
import RevenueCat
import RevenueCatUI

/// Standardized modal sheet presentation for RevenueCatUI's PaywallView,
/// with integrated pacing telemetry, runtime offering resolution, and purchase callbacks.
public struct UniversalPaywallSheet: ViewModifier {
    @Binding public var isPresented: Bool
    public let trigger: String
    public let offeringIdentifier: String?
    public let onPurchaseCompleted: ((CustomerInfo) -> Void)?

    @ObservedObject private var coordinator: UniversalPurchaseCoordinator = .shared
    @State private var offering: Offering? = nil

    public init(
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

    public func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented, onDismiss: {
                PaywallPacingEngine.shared.recordTriggerDismissed(trigger)
                Task {
                    await coordinator.refreshCustomerInfo()
                    if coordinator.isPro {
                        PaywallPacingEngine.shared.recordTriggerPurchased(trigger)
                    }
                }
            }) {
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
                .onPurchaseCompleted { customerInfo in
                    PaywallPacingEngine.shared.recordTriggerPurchased(trigger)
                    onPurchaseCompleted?(customerInfo)
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
}

extension View {
    /// Presents the standardized RevenueCat Paywall sheet with automatic pacing tracking,
    /// offering resolution, and purchase callbacks.
    public func universalPaywall(
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
    public func universalPaywall<T: RawRepresentable>(
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
