import SwiftUI

public struct ReleaseNotesView: View {
    let releaseNotes: [ReleaseNote]
    let onDismiss: () -> Void
    
    public init(releaseNotes: [ReleaseNote], onDismiss: @escaping () -> Void) {
        self.releaseNotes = releaseNotes
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    ForEach(releaseNotes) { note in
                        ReleaseNoteCard(note: note)
                    }
                }
                .padding(.vertical, 24)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(NSLocalizedString("release_notes.title", bundle: .module, value: "What's New", comment: ""))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onDismiss) {
                        Text(NSLocalizedString("common.done", bundle: .module, value: "Done", comment: ""))
                            .bold()
                    }
                }
            }
        }
    }
}

struct ReleaseNoteCard: View {
    let note: ReleaseNote
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let imageName = note.heroImageName {
                Image(imageName, bundle: .module)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
            }
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Version \(note.version)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(note.notes, id: \.self) { point in
                        HStack(alignment: .top, spacing: 12) {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 6, height: 6)
                                .padding(.top, 7)
                            
                            Text(point)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 20)
    }
}

#Preview {
    ReleaseNotesView(
        releaseNotes: [
            ReleaseNote(
                version: "2.0.0",
                notes: [
                    "Added support for multiple bullet points in release notes.",
                    "Implemented optional hero images for each release.",
                    "Improved sheet view to follow Apple design principles.",
                    "Enhanced localization support for better accessibility."
                ],
                heroImageName: "FastingLadyIcon"
            ),
            ReleaseNote(
                version: "1.5.0",
                notes: [
                    "Fixed minor stability issues.",
                    "Performance optimizations for better UI responsiveness."
                ],
                heroImageName: nil
            )
        ],
        onDismiss: {}
    )
}
