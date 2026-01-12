import SwiftUI

public struct ReleaseNotesView: View {
    let releaseNotes: [ReleaseNote]
    let onDismiss: () -> Void
    
    public init(releaseNotes: [ReleaseNote], onDismiss: @escaping () -> Void) {
        self.releaseNotes = Array(releaseNotes.prefix(5))
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        NavigationView {
                ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(releaseNotes) { note in
                        ReleaseNoteCard(note: note)
                        if note.id != releaseNotes.last?.id {
                            Divider()
                                .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(String(format: NSLocalizedString(Constants.StringKeys.feedbackFootnote, bundle: .module, comment: ""), Constants.feedbackEmail))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 24)
                DeveloperSignatureView()
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle(NSLocalizedString("release_notes.title", bundle: .module, value: "What's New", comment: ""))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
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
                let image: Image = {
                    if UIImage(named: imageName, in: .module, with: nil) != nil {
                        return Image(imageName, bundle: .module)
                    } else {
                        return Image(imageName)
                    }
                }()
                
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .cornerRadius(12)
                    .padding(.bottom, 16)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Version \(note.version)")
                    .font(.title3.bold())
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(note.notes, id: \.self) { point in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.accentColor)
                                .padding(.top, 2)
                            
                            Text(point)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
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
                heroImageName: "ReleaseNotes/TallImage"
            )
        ],
        onDismiss: {}
    )
}
