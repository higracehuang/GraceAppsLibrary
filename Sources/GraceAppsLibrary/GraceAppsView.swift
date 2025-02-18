import SwiftUI

public struct GraceAppsView: View {
    let excludingAppId: String?
    
    public init(excludingAppId: String? = nil) {
        self.excludingAppId = excludingAppId
    }
    
    public var body: some View {
        List {
            let apps = GraceAppsLibrary.getAllApps(excluding: excludingAppId)
                .sorted(by: { $0.releaseDate > $1.releaseDate })
            
            ForEach(apps, id: \.self) { app in
                AppLink(
                    iconName: app.iconName,
                    title: app.localizedName,
                    description: app.localizedDescription,
                    url: app.appStoreUrl,
                    isNew: app == apps.first
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
    let isNew: Bool
    
    init(iconName: String, title: String, description: String, url: URL, isNew: Bool = false) {
        self.iconName = iconName
        self.title = title
        self.description = description
        self.url = url
        self.isNew = isNew
    }
    
    var body: some View {
        Link(destination: url) {
            HStack(alignment: .top, spacing: 16) {
                Image(iconName, bundle: .module)
                    .resizable()
                    .frame(width: 60, height: 60)
                    .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.headline)
                        if isNew {
                            Text(Bundle.module.localizedString(forKey: "label.new", value: "New", table: nil))
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .cornerRadius(4)
                        }
                    }
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }
}

#Preview("Grace Apps") {
    GraceAppsView()
} 

public struct GraceAppsNavigationView: View {
    let excludingAppId: String?
    
    public init(excludingAppId: String? = nil) {
        self.excludingAppId = excludingAppId
    }
    
    public var body: some View {
        NavigationLink(destination: GraceAppsView(excludingAppId: excludingAppId)
            .navigationTitle(NSLocalizedString(Constants.StringKeys.otherAppsByGrace, bundle: .module, comment: ""))) {
            Label(NSLocalizedString(Constants.StringKeys.otherAppsBuiltByGrace, bundle: .module, comment: ""), systemImage: "apps.iphone")
        }
    }
} 

#Preview("Navigation View") {
    NavigationView {
        GraceAppsNavigationView()
    }
} 

#Preview("Navigation View excluding TallyCoin") {
    NavigationView {
        GraceAppsNavigationView(excludingAppId: "id1633932632")
    }
} 
