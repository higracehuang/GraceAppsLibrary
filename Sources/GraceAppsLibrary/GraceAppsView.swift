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
                    iconName: app.iconName,
                    title: app.localizedName,
                    description: app.localizedDescription,
                    url: app.appStoreUrl
                )
            }
        }
    }
}

struct AppLink: View {
    let iconName: String
    let title: String
    let description: String
    let url: URL
    
    var body: some View {
        Link(destination: url) {
            HStack(spacing: 16) {
                Image(iconName, bundle: .module)
                    .resizable()
                    .frame(width: 60, height: 60)
                    .cornerRadius(12)
                
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
}

#Preview {
    GraceAppsView()
} 