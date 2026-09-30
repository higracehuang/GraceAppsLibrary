import SwiftUI

public extension View {
    /// Automatically shows release notes if they haven't been viewed for the current version
    /// - Parameters:
    ///   - releaseNotes: The list of available release notes
    ///   - isPaidUser: Whether the user is on a paid tier
    ///   - tierName: The name of the premium tier (default "Premium")
    ///   - suppressOnFirstInstall: Whether to suppress release notes on fresh installs (default true)
    ///   - paywallAction: Custom closure when tapping paywall upgrade CTAs
    /// - Returns: A view that shows release notes in a sheet if needed
    func graceReleaseNotes(
        releaseNotes: [ReleaseNote],
        isPaidUser: Bool = false,
        tierName: LocalizedStringKey = "Premium",
        suppressOnFirstInstall: Bool = true,
        paywallAction: (() -> Void)? = nil
    ) -> some View {
        self.modifier(GraceReleaseNotesModifier(
            releaseNotes: releaseNotes,
            isPaidUser: isPaidUser,
            tierName: tierName,
            suppressOnFirstInstall: suppressOnFirstInstall,
            paywallAction: paywallAction
        ))
    }
    
    @ViewBuilder
    func compatBadge(_ text: String) -> some View {
        if #available(iOS 15.0, *) {
            self.badge(text)
        } else {
            HStack {
                self
                Spacer()
                Text(text)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct GraceReleaseNotesModifier: ViewModifier {
    let releaseNotes: [ReleaseNote]
    let isPaidUser: Bool
    let tierName: LocalizedStringKey
    let suppressOnFirstInstall: Bool
    let paywallAction: (() -> Void)?
    @State private var isPresented = false
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                if ReleaseNotesManager.shared.shouldShow(releaseNotes: releaseNotes, suppressOnFirstInstall: suppressOnFirstInstall) {
                    ReleaseNotesManager.hasShownReleaseNotesThisSession = true
                    isPresented = true
                }
            }
            .sheet(isPresented: $isPresented, onDismiss: {
                ReleaseNotesManager.shared.markCurrentVersionAsViewed()
            }) {
                ReleaseNotesView(releaseNotes: releaseNotes, isPaidUser: isPaidUser, tierName: tierName, paywallAction: paywallAction) {
                    isPresented = false
                    // onDismiss of sheet will call markCurrentVersionAsViewed()
                }
            }
    }
}
