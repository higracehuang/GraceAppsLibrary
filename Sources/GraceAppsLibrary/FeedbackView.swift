import SwiftUI

public struct FeedbackView: View {
    public init() {}
    
    public var body: some View {
      VStack(alignment: .leading, spacing: 16) {
            
            Text("Have thoughts or suggestions? We'd love to hear from you! Your feedback helps us improve. Please send your feedback to:")
            
            Link(Constants.feedbackEmail,
                 destination: URL(string: "mailto:\(Constants.feedbackEmail)")!)

            Text("Appreciate it! ❤️")

            Text("- Grace")
        }
        .padding()
    }
}

#Preview {
    FeedbackView()
} 
