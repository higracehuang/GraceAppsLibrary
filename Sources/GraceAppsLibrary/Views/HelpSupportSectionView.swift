import SwiftUI

public struct HelpSupportSectionView<SourcesDestination: View>: View {
    let faqSections: [FAQSection]?
    let sourcesDestination: SourcesDestination?
    let showFeedback: Bool
    
    // Initializer when sources is NOT provided
    public init(
        faqSections: [FAQSection]? = nil,
        showFeedback: Bool = true
    ) where SourcesDestination == EmptyView {
        self.faqSections = faqSections
        self.sourcesDestination = nil
        self.showFeedback = showFeedback
    }
    
    // Initializer when sources IS provided
    public init(
        faqSections: [FAQSection]? = nil,
        @ViewBuilder sourcesDestination: () -> SourcesDestination,
        showFeedback: Bool = true
    ) {
        self.faqSections = faqSections
        self.sourcesDestination = sourcesDestination()
        self.showFeedback = showFeedback
    }
    
    public var body: some View {
        Section(header: Text(LocalizedStringKey(Constants.StringKeys.supportSectionTitle), bundle: .module)) {
            if let faqSections = faqSections, !faqSections.isEmpty {
                FAQNavigationView(sections: faqSections)
            }
            
            if let sourcesDestination = sourcesDestination {
                NavigationLink(destination: sourcesDestination) {
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
            sourcesDestination: { Text("Sources") }
        )
        
        HelpSupportSectionView(
            faqSections: nil,
            showFeedback: true
        )
    }
}
