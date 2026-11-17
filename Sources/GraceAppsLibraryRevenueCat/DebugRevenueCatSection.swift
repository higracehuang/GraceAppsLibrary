import SwiftUI
import GraceAppsLibrary
import RevenueCat
import RevenueCatUI

/// A turnkey debug settings Section that connects directly to `UniversalPurchaseCoordinator`.
/// Provides a 3-way entitlement override segmented picker, live status badge,
/// paywall presentation button, and dynamic RevenueCat offerings tester.
public struct DebugRevenueCatSection: View {
    @ObservedObject private var coordinator = UniversalPurchaseCoordinator.shared
    @State private var availableOfferings: [Offering] = []
    @State private var isLoadingOfferings = false
    @State private var showPaywallSheet = false

    public let title: String
    public let showOfferingsTester: Bool
    public let showDiagnostics: Bool

    public init(
        title: String? = nil,
        showOfferingsTester: Bool = true,
        showDiagnostics: Bool = false
    ) {
        self.title = title ?? "Entitlements & Paywall"
        self.showOfferingsTester = showOfferingsTester
        self.showDiagnostics = showDiagnostics
    }

    public var body: some View {
        Section(
            header: Text(verbatim: title),
            footer: Text(verbatim: "Override subscription checks to test free vs. pro gates throughout the app.")
        ) {
            #if DEBUG
            // MARK: - Status Badge & Tier Name
            HStack {
                Label(coordinator.tierName, systemImage: "crown")
                Spacer()
                DebugStatusBadge(statusBadge.text, color: statusBadge.color)
            }

            // MARK: - 3-Way Segmented Control
            Picker("Subscription Override", selection: $coordinator.debugOverride) {
                ForEach(DebugEntitlementOverride.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            #endif

            // MARK: - Test Paywall Sheet Button
            Button {
                coordinator.showPaywall = true
                showPaywallSheet = true
            } label: {
                Label("Test Paywall Sheet", systemImage: "sparkles")
            }

            // MARK: - Dynamic RevenueCat Offerings Tester
            if showOfferingsTester && !availableOfferings.isEmpty {
                Picker("Paywall Offering", selection: $coordinator.selectedOfferingIdentifier) {
                    Text("Default Offering").tag(nil as String?)
                    ForEach(availableOfferings, id: \.identifier) { offering in
                        Text(offering.identifier).tag(Optional(offering.identifier))
                    }
                }
            }

            // MARK: - Diagnostics
            if showDiagnostics, let info = coordinator.customerInfo {
                HStack {
                    Text("App User ID")
                    Spacer()
                    Text(info.originalAppUserId)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                HStack {
                    Text("Active Entitlements")
                    Spacer()
                    let active = info.entitlements.all.filter { $0.value.isActive }.keys.joined(separator: ", ")
                    Text(active.isEmpty ? "None" : active)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
        .task {
            if showOfferingsTester {
                self.availableOfferings = await coordinator.loadOfferings()
            }
        }
        .sheet(isPresented: $showPaywallSheet) {
            RevenueCatPaywallHostView(offeringIdentifier: coordinator.selectedOfferingIdentifier)
        }
    }

    #if DEBUG
    private var statusBadge: (text: LocalizedStringKey, color: Color) {
        switch coordinator.debugOverride {
        case .forcePro:
            return ("Pro (Forced)", .orange)
        case .forceFree:
            return ("Free (Forced)", .orange)
        case .automatic:
            return (coordinator.storeIsPro ? "Active (Store)" : "Free (Store)", coordinator.storeIsPro ? .green : .secondary)
        }
    }
    #endif
}

/// Helper host presenting RevenueCatUI's PaywallView with pacing registration on appear & dismiss.
public struct RevenueCatPaywallHostView: View {
    public let offeringIdentifier: String?
    @Environment(\.dismiss) private var dismiss
    @State private var offering: Offering? = nil

    public init(offeringIdentifier: String? = nil) {
        self.offeringIdentifier = offeringIdentifier
    }

    public var body: some View {
        Group {
            if let offering = offering {
                PaywallView(offering: offering, displayCloseButton: true)
            } else {
                PaywallView(displayCloseButton: true)
            }
        }
        .onAppear {
            PaywallPacingEngine.shared.recordTriggerShown("debug_paywall_sheet")
        }
        .onDisappear {
            PaywallPacingEngine.shared.recordTriggerDismissed("debug_paywall_sheet")
            if UniversalPurchaseCoordinator.shared.isPro {
                PaywallPacingEngine.shared.recordTriggerPurchased("debug_paywall_sheet")
            }
        }
        .task {
            if let identifier = offeringIdentifier {
                let offerings = await UniversalPurchaseCoordinator.shared.loadOfferings()
                self.offering = offerings.first { $0.identifier == identifier }
            }
        }
    }
}
