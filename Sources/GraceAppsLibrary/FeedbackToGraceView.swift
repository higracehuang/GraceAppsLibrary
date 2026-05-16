import SwiftUI
import UIKit

public struct FeedbackToGraceView: View {
    public init() {}
    
    private var feedbackURL: URL {
        let appName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "App"
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        let deviceModel = UIDevice.current.model
        let systemVersion = UIDevice.current.systemVersion
        
        let subject = "Feedback: \(appName)"
        let body = """


---
App: \(appName)
Version: \(appVersion) (\(appBuild))
Device: \(deviceModel) (iOS \(systemVersion))
"""
        
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        return URL(string: "mailto:\(Constants.feedbackEmail)?subject=\(encodedSubject)&body=\(encodedBody)")!
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 20) {
                    Text(Bundle.module.localizedString(forKey: Constants.StringKeys.feedbackMessage, value: nil, table: nil))
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineSpacing(6)
                    
                    Link(destination: feedbackURL) {
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