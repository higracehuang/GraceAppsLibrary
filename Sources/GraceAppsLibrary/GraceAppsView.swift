import SwiftUI
import UIKit

public struct GraceAppsView: View {
  let excludingAppId: String?
  
  public init(excludingAppId: String? = nil) {
    self.excludingAppId = excludingAppId
  }
  
  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        // App Store style introduction
        VStack(alignment: .leading, spacing: 8) {
          Text(Bundle.module.localizedString(forKey: Constants.StringKeys.appsIntroduction, value: nil, table: nil))
            .font(.subheadline)
            .foregroundColor(.secondary)
            .lineSpacing(4)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)

        let apps = GraceAppsLibrary.getSortedApps(excluding: excludingAppId)
        let categories = Array(Set(apps.map { $0.category })).sorted(by: { $0.rawValue < $1.rawValue })
        
        ForEach(categories, id: \.self) { category in
          VStack(alignment: .leading, spacing: 12) {
            Text(category.rawValue.uppercased())
              .font(.footnote.bold())
              .foregroundColor(.secondary)
              .padding(.horizontal, 24)
            
            VStack(spacing: 0) {
              let categoryApps = apps.filter { $0.category == category }
              ForEach(categoryApps, id: \.self) { app in
                AppRow(
                  iconName: app.iconName,
                  title: app.localizedName,
                  description: app.localizedDescription,
                  url: app.appStoreUrl,
                  isNew: app == apps.first
                )
                
                if app != categoryApps.last {
                  Divider()
                    .padding(.leading, 84)
                }
              }
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .padding(.horizontal, 16)
          }
        }
        
        DeveloperSignatureView()
      }
      .padding(.bottom, 40)
    }
    .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
  }
}

struct AppRow: View {
  let iconName: String
  let title: String
  let description: String
  let url: URL
  let isNew: Bool
  
  var body: some View {
    Link(destination: url) {
      HStack(alignment: .center, spacing: 16) {
        Image(iconName, bundle: .module)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 52, height: 52)
          .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
              .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
          )
        
        VStack(alignment: .leading, spacing: 3) {
          HStack(alignment: .center, spacing: 6) {
            Text(title)
              .font(.system(.headline, design: .rounded))
              .foregroundColor(.primary)
            
            if isNew {
              Text(NSLocalizedString(Constants.StringKeys.labelNew, bundle: .module, comment: ""))
                .font(.system(size: 8, weight: .black))
                .foregroundColor(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.accentColor)
                .clipShape(Capsule())
            }
          }
          
          Text(description)
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
        }
        
        Spacer()
        
        Text(NSLocalizedString(Constants.StringKeys.labelGet, bundle: .module, comment: ""))
          .font(.subheadline.bold())
          .foregroundColor(.accentColor)
          .padding(.horizontal, 16)
          .padding(.vertical, 6)
          .background(Color.accentColor.opacity(0.12))
          .clipShape(Capsule())
      }
      .padding(.vertical, 14)
      .padding(.horizontal, 16)
      .contentShape(Rectangle())
    }
    .buttonStyle(PlainButtonStyle())
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
