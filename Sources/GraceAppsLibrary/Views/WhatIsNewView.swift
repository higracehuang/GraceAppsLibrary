import SwiftUI

internal struct WhatIsNewView: View {
    let releaseNotes: [ReleaseNote]
    let isPaidUser: Bool
    let tierName: LocalizedStringKey
    let paywallAction: (() -> Void)?

    @State private var showingReleaseNotes = false
    @State private var pendingPaywallAction = false
    
    internal init(releaseNotes: [ReleaseNote], isPaidUser: Bool = false, tierName: LocalizedStringKey = "Premium", paywallAction: (() -> Void)? = nil) {
        self.releaseNotes = releaseNotes
        self.isPaidUser = isPaidUser
        self.tierName = tierName
        self.paywallAction = paywallAction
    }
    
    internal var body: some View {
        Button(action: {
            showingReleaseNotes = true
        }) {
            Label(NSLocalizedString(Constants.StringKeys.releaseNotesTitle, bundle: .module, value: "What's New", comment: ""), systemImage: "sparkles")
        }
        .sheet(isPresented: $showingReleaseNotes, onDismiss: {
            if pendingPaywallAction {
                pendingPaywallAction = false
                paywallAction?()
            }
        }) {
            ReleaseNotesView(
                releaseNotes: releaseNotes,
                isPaidUser: isPaidUser,
                tierName: tierName,
                paywallAction: paywallAction.map { _ in
                    {
                        pendingPaywallAction = true
                        showingReleaseNotes = false
                    }
                }
            ) {
                showingReleaseNotes = false
            }
        }
    }
}

#Preview {
    List {
        WhatIsNewView(
            releaseNotes: [
                ReleaseNote(
                    version: "1.0.0",
                    notes: ["Initial release notes for testing."]
                )
            ]
        )
    }
}
