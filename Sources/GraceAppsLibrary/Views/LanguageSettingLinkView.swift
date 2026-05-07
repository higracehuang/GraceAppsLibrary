import SwiftUI

public struct LanguageSettingLinkView: View {
    public init() {}
    
    public var body: some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } label: {
            Label(LocalizedStringKey(Bundle.module.localizedString(forKey: "settings.language", value: nil, table: nil)), 
                  systemImage: "globe")
                .compatBadge(Locale.current.localizedString(forIdentifier: Locale.preferredLanguages.first ?? "en") ?? "")
        }
    }
}

#Preview {
    Form {
        LanguageSettingLinkView()
    }
}
