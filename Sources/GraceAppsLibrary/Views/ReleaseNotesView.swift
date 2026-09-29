import SwiftUI

public struct ReleaseNotesView: View {
    let releaseNotes: [ReleaseNote]
    let isPaidUser: Bool
    let tierName: LocalizedStringKey
    let paywallAction: (() -> Void)?
    let onDismiss: () -> Void

    
    public init(releaseNotes: [ReleaseNote], isPaidUser: Bool = false, tierName: LocalizedStringKey = "Premium", paywallAction: (() -> Void)? = nil, onDismiss: @escaping () -> Void) {
        self.releaseNotes = Array(releaseNotes.prefix(5))
        self.isPaidUser = isPaidUser
        self.tierName = tierName
        self.paywallAction = paywallAction
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        let firstPaidNoteId = releaseNotes.first(where: { $0.hasPaidFeature && !$0.hasCustomCTA })?.id
        
        NavigationView {
                ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(releaseNotes) { note in
                        ReleaseNoteCard(
                            note: note,
                            isPaidUser: isPaidUser,
                            tierName: tierName,
                            paywallAction: paywallAction,
                            isFirstPaidNote: note.id == firstPaidNoteId
                        )
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
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(Text("Close"))
                }
            }
        }
    }
}

struct ReleaseNoteCard: View {
    let note: ReleaseNote
    let isPaidUser: Bool
    let tierName: LocalizedStringKey
    let paywallAction: (() -> Void)?
    let isFirstPaidNote: Bool
    
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
                
                if let url = note.effectiveHeroImageURL {
                    Link(destination: url) {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.bottom, 16)
                } else {
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 16)
                }
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
                                
                                if item.isPaidFeature {
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
                
                // MARK: - Call To Action (Custom CTA or Paywall)
                if note.hasCustomCTA {
                    let shouldShow = !note.effectiveRequiresUnpaidUser || !isPaidUser
                    if shouldShow, let ctaTitle = note.ctaTitle {
                        if let url = note.ctaURL, note.ctaAction == nil {
                            Link(destination: url) {
                                ctaButtonLabel(title: ctaTitle, systemImage: note.ctaSystemImage)
                            }
                            .padding(.top, 8)
                        } else {
                            Button(action: {
                                note.ctaAction?()
                                if let url = note.ctaURL {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                ctaButtonLabel(title: ctaTitle, systemImage: note.ctaSystemImage)
                            }
                            .padding(.top, 8)
                        }
                    }
                } else if isFirstPaidNote && !isPaidUser {
                    if let action = paywallAction {
                        Button(action: action) {
                            Text("release_notes.upgrade_to \(Text(tierName))", bundle: .module)
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
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private func ctaButtonLabel(title: LocalizedStringKey, systemImage: String?) -> some View {
        HStack(spacing: 8) {
            if let systemImage = systemImage {
                Image(systemName: systemImage)
                    .font(.headline)
            }
            Text(title)
                .font(.headline)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.accentColor)
        .cornerRadius(10)
    }
}

#Preview("Free User") {
    ReleaseNotesView(
        releaseNotes: [
            ReleaseNote(
                version: "2.0.0",
                items: [
                    ReleaseNoteItem(text: "Added support for multiple bullet points in release notes."),
                    ReleaseNoteItem(text: "Implemented optional hero images for each release.", isPaidFeature: true),
                    ReleaseNoteItem(text: "Improved sheet view to follow Apple design principles.", isPaidFeature: true),
                    ReleaseNoteItem(text: "Enhanced localization support for better accessibility.")
                ],
                heroImageName: "FastingLadyIcon",
                ctaTitle: "Upgrade to Pro",
                ctaAction: {}
            )
        ],
        isPaidUser: false,
        tierName: "Unlimited Access",
        onDismiss: {}
    )
}

#Preview("Paid User") {
    ReleaseNotesView(
        releaseNotes: [
            ReleaseNote(
                version: "2.0.0",
                items: [
                    ReleaseNoteItem(text: "Added support for multiple bullet points in release notes."),
                    ReleaseNoteItem(text: "Implemented optional hero images for each release.", isPaidFeature: true),
                    ReleaseNoteItem(text: "Improved sheet view to follow Apple design principles.", isPaidFeature: true),
                    ReleaseNoteItem(text: "Enhanced localization support for better accessibility.")
                ],
                heroImageName: "FastingLadyIcon",
                ctaTitle: "Upgrade to Pro",
                ctaAction: {}
            )
        ],
        isPaidUser: true,
        tierName: "Unlimited Access",
        onDismiss: {}
    )
}

#Preview("Website & Cross Promotion") {
    ReleaseNotesView(
        releaseNotes: [
            ReleaseNote(
                version: "2.1.0",
                notes: [
                    "Introducing cross-app sync with our companion app Dial In Pourovers!",
                    "Seamlessly share your coffee beans between espresso and pour over."
                ],
                ctaTitle: "Get Dial In Pourovers",
                ctaURL: URL(string: "https://apps.apple.com"),
                ctaSystemImage: "arrow.down.app"
            ),
            ReleaseNote(
                version: "2.0.0",
                notes: [
                    "New detailed coffee guide available on our website."
                ],
                ctaTitle: "Read the Brewing Guide",
                ctaURL: URL(string: "https://ujiapps.com"),
                ctaSystemImage: "safari"
            )
        ],
        isPaidUser: true,
        tierName: "Unlimited Access",
        onDismiss: {}
    )
}
