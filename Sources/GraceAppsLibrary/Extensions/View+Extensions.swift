import SwiftUI

public extension View {
    /// Automatically shows release notes if they haven't been viewed for the current version
    /// - Parameter releaseNotes: The list of available release notes
    /// - Returns: A view that shows release notes in a sheet if needed
    func graceReleaseNotes(releaseNotes: [ReleaseNote]) -> some View {
        self.modifier(GraceReleaseNotesModifier(releaseNotes: releaseNotes))
    }
}

struct GraceReleaseNotesModifier: ViewModifier {
    let releaseNotes: [ReleaseNote]
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
                ReleaseNotesView(releaseNotes: releaseNotes) {
                    isPresented = false
                    // onDismiss of sheet will call markCurrentVersionAsViewed()
                }
            }
    }
}
