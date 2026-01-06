import SwiftUI

public struct WhatIsNewView: View {
    let releaseNotes: [ReleaseNote]
    @State private var showingReleaseNotes = false
    
    public init(releaseNotes: [ReleaseNote]) {
        self.releaseNotes = releaseNotes
    }
    
    public var body: some View {
        Button(action: {
            showingReleaseNotes = true
        }) {
            Label(NSLocalizedString("release_notes.title", bundle: .module, value: "What's New", comment: ""), systemImage: "sparkles")
        }
        .sheet(isPresented: $showingReleaseNotes) {
            ReleaseNotesView(releaseNotes: releaseNotes) {
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
