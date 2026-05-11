import SwiftUI

public extension View {
    /// Automatically shows release notes if they haven't been viewed for the current version
    /// - Parameter releaseNotes: The list of available release notes
    /// - Returns: A view that shows release notes in a sheet if needed
    func graceReleaseNotes(releaseNotes: [ReleaseNote], isPaidUser: Bool = false, tierName: LocalizedStringKey = "Premium") -> some View {
        self.modifier(GraceReleaseNotesModifier(releaseNotes: releaseNotes, isPaidUser: isPaidUser, tierName: tierName))
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
    let paywallAction: (() -> Void)?
    @State private var isPresented = false
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                if ReleaseNotesManager.shared.shouldShow(releaseNotes: releaseNotes) {
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
