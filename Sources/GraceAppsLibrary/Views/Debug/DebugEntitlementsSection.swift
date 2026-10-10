import SwiftUI

/// An override state for debug testing of app subscription & entitlement gates.
public enum DebugEntitlementOverride: String, CaseIterable, Identifiable {
    case automatic = "Automatic"
    case forcePro = "Force Pro"
    case forceFree = "Force Free"

    public var id: String { rawValue }
}

/// A reusable debug section for viewing and toggling Unlimited Access / Pro entitlements.
public struct DebugEntitlementsSection: View {
    public let entitlementOverride: Binding<DebugEntitlementOverride>?
    public let effectiveIsPro: Bool?
    public let unlimitedAccess: Binding<Bool>?
    public let tierName: String
    public let paywallAction: (() -> Void)?

    /// Initializer for 3-way entitlement override (Automatic / Force Pro / Force Free).
    public init(
        override: Binding<DebugEntitlementOverride>,
        effectiveIsPro: Bool? = nil,
        tierName: String = "Unlimited Access",
        paywallAction: (() -> Void)? = nil
    ) {
        self.entitlementOverride = override
        self.effectiveIsPro = effectiveIsPro
        self.unlimitedAccess = nil
        self.tierName = tierName
        self.paywallAction = paywallAction
    }

    /// Initializer for 2-way toggle (legacy / simple).
    public init(
        unlimitedAccess: Binding<Bool>,
        tierName: String = "Unlimited Access",
        paywallAction: (() -> Void)? = nil
    ) {
        self.entitlementOverride = nil
        self.effectiveIsPro = nil
        self.unlimitedAccess = unlimitedAccess
        self.tierName = tierName
        self.paywallAction = paywallAction
    }

    public var body: some View {
        Section(
            header: Text("Entitlements & Paywall"),
            footer: Text("Override subscription checks to test free vs. pro gates throughout the app.")
        ) {
            if let override = entitlementOverride {
                HStack {
                    Label(tierName, systemImage: "crown")
                    Spacer()
                    DebugStatusBadge(statusBadge.text, color: statusBadge.color)
                }

                Picker("Subscription Override", selection: override) {
                    ForEach(DebugEntitlementOverride.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            } else if let unlimitedAccess = unlimitedAccess {
                HStack {
                    Text(tierName)
                    Spacer()
                    DebugStatusBadge(unlimitedAccess.wrappedValue ? "Active" : "Inactive", isActive: unlimitedAccess.wrappedValue)
                }

                Toggle(isOn: unlimitedAccess) {
                    Label("Unlock \(tierName)", systemImage: "crown")
                }
            }

            if let paywallAction = paywallAction {
                Button(action: paywallAction) {
                    Label("Test Paywall Sheet", systemImage: "sparkles")
                }
            }
        }
    }

    private var statusBadge: (text: LocalizedStringKey, color: Color) {
        guard let override = entitlementOverride?.wrappedValue else {
            return ("Inactive", .secondary)
        }
        switch override {
        case .forcePro:
            return ("Pro (Forced)", .orange)
        case .forceFree:
            return ("Free (Forced)", .orange)
        case .automatic:
            if let isPro = effectiveIsPro {
                return (isPro ? "Active (Store)" : "Free (Store)", isPro ? .green : .secondary)
            } else {
                return ("Automatic", .green)
            }
        }
    }
}
