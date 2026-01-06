import SwiftUI

public struct ReleaseNotesDebugView: View {
    let releaseNotes: [ReleaseNote]
    @State private var showingReleaseNotes = false
    
    public init(releaseNotes: [ReleaseNote]) {
        self.releaseNotes = releaseNotes
    }
    
    public var body: some View {
        Button(action: {
            showingReleaseNotes = true
        }) {
            Label("Show Release Notes (Debug)", systemImage: "sparkles")
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
        ReleaseNotesDebugView(
            releaseNotes: [
                ReleaseNote(
                    version: "1.0.0",
                    notes: ["Initial debug release notes."]
                )
            ]
        )
    }
}
