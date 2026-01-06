import SwiftUI
import UIKit

public struct FeedbackToGraceView: View {
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 20) {
                    Text(Bundle.module.localizedString(forKey: Constants.StringKeys.feedbackMessage, value: nil, table: nil))
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineSpacing(6)
                    
                    Link(destination: URL(string: "mailto:\(Constants.feedbackEmail)")!) {
                        HStack {
                            Image(systemName: "envelope.fill")
                            Text(Constants.feedbackEmail)
                                .fontWeight(.semibold)
                        }
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Bundle.module.localizedString(forKey: Constants.StringKeys.feedbackAppreciation, value: nil, table: nil))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(Bundle.module.localizedString(forKey: Constants.StringKeys.feedbackSignature, value: nil, table: nil))
                            .font(.subheadline.italic())
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                }
                .padding(24)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                
                DeveloperSignatureView()
            }
            .padding(20)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
    }
}

#Preview {
    FeedbackToGraceView()
} 

public struct FeedbackToGraceNavigationView: View {
    public init() {}

    public var body: some View {
        NavigationLink(destination: FeedbackToGraceView().navigationTitle(Bundle.module.localizedString(forKey: Constants.StringKeys.feedbackTitle, value: nil, table: nil))) {
            Label(Bundle.module.localizedString(forKey: Constants.StringKeys.feedbackTitle, value: nil, table: nil), 
                  systemImage: "envelope")
        }
    }
}

#Preview {
    NavigationView {
        FeedbackToGraceNavigationView()
    }
}