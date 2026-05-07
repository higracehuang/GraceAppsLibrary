import SwiftUI

/// A reusable Settings `Section` that links to the developer's other apps.
public struct AboutDeveloperSectionView: View {
    let excludingAppId: String?
    
    /// - Parameter excludingAppId: The App Store ID of the current app to exclude from the list.
    public init(excludingAppId: String? = nil) {
        self.excludingAppId = excludingAppId
    }
    
    public var body: some View {
        Section(header: Text(LocalizedStringKey(Constants.StringKeys.developerSectionTitle), bundle: .module)) {
            GraceAppsNavigationView(excludingAppId: excludingAppId)
        }
    }
}

#Preview {
    NavigationView {
        Form {
            AboutDeveloperSectionView()
        }
    }
}
