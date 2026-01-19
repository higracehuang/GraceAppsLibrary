import SwiftUI

public struct LegalSectionView: View {
    public let privacyPolicyURL: URL
    public let termsOfUseURL: URL
    
    public init(privacyPolicyURL: URL, termsOfUseURL: URL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
        self.privacyPolicyURL = privacyPolicyURL
        self.termsOfUseURL = termsOfUseURL
    }
    
    public var body: some View {
        Section(header: Text(LocalizedStringKey(Bundle.module.localizedString(forKey: "legal.section", value: nil, table: nil)))) {
            Link(destination: privacyPolicyURL) {
                Label(LocalizedStringKey(Bundle.module.localizedString(forKey: "legal.privacy_policy", value: nil, table: nil)), 
                      systemImage: "hand.raised")
            }
            
            Link(destination: termsOfUseURL) {
                Label(LocalizedStringKey(Bundle.module.localizedString(forKey: "legal.terms_of_use", value: nil, table: nil)), 
                      systemImage: "doc.text")
            }
        }
    }
}

#Preview {
    Form {
        LegalSectionView(privacyPolicyURL: URL(string: "https://example.com/privacy")!)
    }
}
