import SwiftUI

public struct WhatIsNewView: View {
    let releaseNotes: [ReleaseNote]
    let isPaidUser: Bool
    let tierName: LocalizedStringKey
    let paywallAction: (() -> Void)?

    @State private var showingReleaseNotes = false
    
    public init(releaseNotes: [ReleaseNote], isPaidUser: Bool = false, tierName: LocalizedStringKey = "Premium", paywallAction: (() -> Void)? = nil) {
        self.releaseNotes = releaseNotes
        self.isPaidUser = isPaidUser
        self.tierName = tierName
        self.paywallAction = paywallAction
    }
    
    public var body: some View {
        Button(action: {
            showingReleaseNotes = true
        }) {
            Label(NSLocalizedString(Constants.StringKeys.releaseNotesTitle, bundle: .module, value: "What's New", comment: ""), systemImage: "sparkles")
        }
        .sheet(isPresented: $showingReleaseNotes) {
            ReleaseNotesView(releaseNotes: releaseNotes, isPaidUser: isPaidUser, tierName: tierName, paywallAction: paywallAction) {
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
