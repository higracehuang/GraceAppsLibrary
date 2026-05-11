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
            .navigationTitle(NSLocalizedString(Constants.StringKeys.releaseNotesTitle, bundle: .module, value: "What's New", comment: ""))
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
            
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(NSLocalizedString(Constants.StringKeys.releaseNotesVersionPrefix, bundle: .module, value: "Version", comment: ""))
                        .font(.footnote.bold())
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    Text(note.version)
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(note.items) { item in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.accentColor.opacity(0.8))
                                .padding(.top, 2)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.text)
                                    .font(.body)
                                    .foregroundColor(.primary.opacity(0.8))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineSpacing(2)
                                
                                if let tierName = item.tierName {
                                    HStack(spacing: 4) {
                                        let prefix = NSLocalizedString(Constants.StringKeys.releaseNotesTierPrefix, bundle: .module, value: "Included with", comment: "")
                                        let suffix = NSLocalizedString(Constants.StringKeys.releaseNotesTierSuffix, bundle: .module, value: "", comment: "")
                                        
                                        if !prefix.isEmpty {
                                            Text(prefix)
                                                .font(.system(size: 8))
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Text(tierName)
                                            .font(.system(size: 10, weight: .bold))
                                        
                                        if !suffix.isEmpty {
                                            Text(suffix)
                                                .font(.system(size: 8))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(Color.accentColor.opacity(0.08))
                                    )
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(Color.accentColor.opacity(0.15), lineWidth: 0.5)
                                    )
                                    .foregroundColor(Color.accentColor)
                                    .padding(.top, 2)
                                }
                            }
                        }
                    }
                }
                
                if let ctaTitle = note.ctaTitle, let action = note.ctaAction {
                    Button(action: action) {
                        Text(ctaTitle)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .cornerRadius(10)
                    }
                    .padding(.top, 8)
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
                items: [
                    ReleaseNoteItem(text: "Added support for multiple bullet points in release notes."),
                    ReleaseNoteItem(text: "Implemented optional hero images for each release.", tierName: "PRO"),
                    ReleaseNoteItem(text: "Improved sheet view to follow Apple design principles.", tierName: "Premium"),
                    ReleaseNoteItem(text: "Enhanced localization support for better accessibility.")
                ],
                heroImageName: "FastingLadyIcon",
                ctaTitle: "Upgrade to Pro",
                ctaAction: {}
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
