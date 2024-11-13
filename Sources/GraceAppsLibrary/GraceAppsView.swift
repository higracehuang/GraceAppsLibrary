import SwiftUI

public struct GraceAppsView: View {
    let excludingAppId: String?
    
    public init(excludingAppId: String? = nil) {
        self.excludingAppId = excludingAppId
    }
    
    public var body: some View {
        List {
            ForEach(GraceAppsLibrary.getAllApps(excluding: excludingAppId), id: \.self) { app in
                AppLink(
                    title: app.localizedName,
                    description: app.localizedDescription,
                    url: app.appStoreUrl
                )
            }
        }
    }
}

struct AppLink: View {
    let title: String
    let description: String
    let url: URL
    
    var body: some View {
        Link(destination: url) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}

#Preview {
    GraceAppsView()
} 