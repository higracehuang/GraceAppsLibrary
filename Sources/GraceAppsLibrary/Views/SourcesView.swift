import SwiftUI

struct SourcesView: View {
    let sections: [SourceSection]
    let disclaimer: LocalizedStringKey?
    let navigationTitle: LocalizedStringKey
    
    init(
        sections: [SourceSection],
        disclaimer: LocalizedStringKey? = nil,
        navigationTitle: LocalizedStringKey? = nil
    ) {
        self.sections = sections
        self.disclaimer = disclaimer
        self.navigationTitle = navigationTitle ?? LocalizedStringKey(Bundle.module.localizedString(forKey: Constants.StringKeys.supportSourcesReferences, value: nil, table: nil))
    }
    
    var body: some View {
        Form {
            ForEach(sections) { section in
                Section(
                    header: Text(section.title),
                    footer: section.footer.map { Text($0) }
                ) {
                    ForEach(section.links) { link in
                        Link(destination: link.url) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(link.title)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                if let subtitle = link.subtitle {
                                    Text(subtitle)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            
            if let disclaimer = disclaimer {
                Section(header: Text(LocalizedStringKey(Constants.StringKeys.supportDisclaimer), bundle: .module)) {
                    Text(disclaimer)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        SourcesView(
            sections: [
                SourceSection(
                    title: "Books",
                    footer: "Foundational books.",
                    links: [
                        SourceLink(title: "Book Title", subtitle: "Author Name", url: URL(string: "https://example.com")!)
                    ]
                )
            ],
            disclaimer: "This is a disclaimer."
        )
    }
}
