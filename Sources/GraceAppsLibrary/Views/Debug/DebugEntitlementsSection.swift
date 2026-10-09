import SwiftUI

/// A reusable debug section for viewing and toggling Unlimited Access / Pro entitlements.
public struct DebugEntitlementsSection: View {
    @Binding public var unlimitedAccess: Bool
    public let tierName: String
    public let paywallAction: (() -> Void)?
    
    public init(
        unlimitedAccess: Binding<Bool>,
        tierName: String = "Unlimited Access",
        paywallAction: (() -> Void)? = nil
    ) {
        self._unlimitedAccess = unlimitedAccess
        self.tierName = tierName
        self.paywallAction = paywallAction
    }
    
    public var body: some View {
        Section(header: Text("Entitlements & Paywall")) {
            HStack {
                Text(tierName)
                Spacer()
                DebugStatusBadge(unlimitedAccess ? "Active" : "Inactive", isActive: unlimitedAccess)
            }
            
            Toggle(isOn: $unlimitedAccess) {
                Label("Unlock \(tierName)", systemImage: "crown")
            }
            
            if let paywallAction = paywallAction {
                Button(action: paywallAction) {
                    Label("Test Paywall Sheet", systemImage: "sparkles")
                }
            }
        }
    }
}
