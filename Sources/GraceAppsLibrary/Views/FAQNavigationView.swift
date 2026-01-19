import SwiftUI

public struct FAQView: View {
    public let sections: [FAQSection]
    public let navigationTitle: LocalizedStringKey
    
    public init(sections: [FAQSection], navigationTitle: LocalizedStringKey = "FAQs") {
        self.sections = sections
        self.navigationTitle = navigationTitle
    }
    
    public var body: some View {
        List {
            ForEach(sections) { section in
                Section(header: Text(section.title)) {
                    ForEach(section.items) { item in
                        DisclosureGroup(
                            content: {
                                Text(item.answer)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 4)
                                    .padding(.leading, 2)
                            },
                            label: {
                                Text(item.question)
                                    .font(.headline)
                                    .fontWeight(.medium)
                            }
                        )
                    }
                }
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
    }
}

public struct FAQNavigationView: View {
    public let sections: [FAQSection]
    public let navigationTitle: LocalizedStringKey
    public let systemImage: String
    
    public init(sections: [FAQSection], navigationTitle: LocalizedStringKey? = nil, systemImage: String = "questionmark.circle") {
        self.sections = sections
        self.navigationTitle = navigationTitle ?? LocalizedStringKey(Bundle.module.localizedString(forKey: "faq.title", value: nil, table: nil))
        self.systemImage = systemImage
    }
    
    public var body: some View {
        NavigationLink(destination: FAQView(sections: sections, navigationTitle: navigationTitle)) {
            Label(navigationTitle, systemImage: systemImage)
        }
    }
}

#Preview {
    NavigationView {
        List {
            FAQNavigationView(sections: [
                FAQSection(
                    title: "Basics",
                    items: [
                        FAQItem(question: "Question 1", answer: "Answer 1"),
                        FAQItem(question: "Question 2", answer: "Answer 2")
                    ]
                )
            ])
        }
    }
}
