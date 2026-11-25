import SwiftUI

/// Reusable Watch empty-state view with optional iCloud sign-in diagnostics and refresh action.
public struct WatchEmptyStateView: View {
    private let systemImage: String
    private let title: LocalizedStringKey
    private let subtitle: LocalizedStringKey?
    private let showICloudStatus: Bool
    private let containerIdentifier: String?
    private let onRefresh: (() -> Void)?

    @State private var iCloudAvailability: WatchICloudAvailability?

    public init(
        systemImage: String = "tray",
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        showICloudStatus: Bool = false,
        containerIdentifier: String? = nil,
        onRefresh: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
        self.showICloudStatus = showICloudStatus
        self.containerIdentifier = containerIdentifier
        self.onRefresh = onRefresh
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                if showICloudStatus && isICloudUnavailable {
                    Label {
                        Text("iCloud Unavailable", bundle: .module)
                            .font(.caption.bold())
                    } icon: {
                        Image(systemName: "icloud.slash")
                    }
                    .foregroundStyle(.orange)

                    Text("Sign in to iCloud in Settings on your iPhone and Apple Watch to sync.", bundle: .module)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if let onRefresh {
                    Button(action: onRefresh) {
                        Text("Refresh", bundle: .module)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .task {
            guard showICloudStatus else { return }
            if !WatchICloudStatus.isSignedIn {
                iCloudAvailability = .unavailable
            } else {
                iCloudAvailability = await WatchICloudStatus.availability(containerIdentifier: containerIdentifier)
            }
        }
    }

    private var isICloudUnavailable: Bool {
        if !WatchICloudStatus.isSignedIn { return true }
        return iCloudAvailability == .unavailable || iCloudAvailability == .restricted
    }
}
