import SwiftUI

public struct FeedbackView: View {
    public init() {}
    
    public var body: some View {
      VStack(alignment: .leading, spacing: 16) {
            
            Text(Bundle.module.localizedString(forKey: Constants.StringKeys.feedbackMessage, value: nil, table: nil))
            
            Link(Constants.feedbackEmail,
                 destination: URL(string: "mailto:\(Constants.feedbackEmail)")!)

            Text(Bundle.module.localizedString(forKey: Constants.StringKeys.feedbackAppreciation, value: nil, table: nil))

            Text(Bundle.module.localizedString(forKey: Constants.StringKeys.feedbackSignature, value: nil, table: nil))
        }
        .padding()
    }
}

#Preview {
    FeedbackView()
} 
