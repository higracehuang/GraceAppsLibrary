import SwiftUI

public struct HelpSupportSectionView: View {
    let faqSections: [FAQSection]?
    let sourceSections: [SourceSection]?
    let sourceDisclaimer: LocalizedStringKey?
    let showFeedback: Bool
    
    public init(
        faqSections: [FAQSection]? = nil,
        sourceSections: [SourceSection]? = nil,
        sourceDisclaimer: LocalizedStringKey? = nil,
        showFeedback: Bool = true
    ) {
        self.faqSections = faqSections
        self.sourceSections = sourceSections
        self.sourceDisclaimer = sourceDisclaimer
        self.showFeedback = showFeedback
    }
    
    public var body: some View {
        Section(header: Text(LocalizedStringKey(Constants.StringKeys.supportSectionTitle), bundle: .module)) {
            if let faqSections = faqSections, !faqSections.isEmpty {
                FAQNavigationView(sections: faqSections)
            }
            
            if let sourceSections = sourceSections, !sourceSections.isEmpty {
                NavigationLink(destination: SourcesView(sections: sourceSections, disclaimer: sourceDisclaimer)) {
                    Label {
                        Text(LocalizedStringKey(Constants.StringKeys.supportSourcesReferences), bundle: .module)
                    } icon: {
                        Image(systemName: "book.closed")
                    }
                }
            }
            
            if showFeedback {
                FeedbackToGraceNavigationView()
            }
        }
    }
}

#Preview {
    List {
        HelpSupportSectionView(
            faqSections: [
                FAQSection(title: "General", items: [FAQItem(question: "Q", answer: "A")])
            ],
            sourceSections: [
                SourceSection(title: "Books", links: [SourceLink(title: "B", url: URL(string: "https://x.com")!)])
            ]
        )
        
        HelpSupportSectionView(
            faqSections: nil,
            showFeedback: true
        )
    }
}
