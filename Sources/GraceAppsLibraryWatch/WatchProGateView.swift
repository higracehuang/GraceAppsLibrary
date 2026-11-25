import SwiftUI

/// Reusable Pro-gated container for Watch apps using `WatchSyncChannel<WatchEntitlementEnvelope<Payload>>`.
public struct WatchProGateView<Payload: Codable & Equatable, Content: View>: View {
    @ObservedObject private var channel: WatchSyncChannel<WatchEntitlementEnvelope<Payload>>
    private let lockedTitle: LocalizedStringKey
    private let lockedSubtitle: LocalizedStringKey
    private let refreshTitle: LocalizedStringKey
    private let syncingTitle: LocalizedStringKey
    private let content: (Payload) -> Content

    public init(
        channel: WatchSyncChannel<WatchEntitlementEnvelope<Payload>>,
        lockedTitle: LocalizedStringKey = "Pro Required",
        lockedSubtitle: LocalizedStringKey = "Upgrade to Pro on your iPhone to unlock the Watch app.",
        refreshTitle: LocalizedStringKey = "Refresh",
        syncingTitle: LocalizedStringKey = "Syncing...",
        @ViewBuilder content: @escaping (Payload) -> Content
    ) {
        self.channel = channel
        self.lockedTitle = lockedTitle
        self.lockedSubtitle = lockedSubtitle
        self.refreshTitle = refreshTitle
        self.syncingTitle = syncingTitle
        self.content = content
    }

    public var body: some View {
        Group {
            if let envelope = channel.state {
                if envelope.isPro {
                    content(envelope.payload)
                } else {
                    WatchProRequiredView(
                        title: lockedTitle,
                        subtitle: lockedSubtitle,
                        refreshTitle: refreshTitle,
                        onRefresh: { channel.requestStateFromCounterpart() }
                    )
                }
            } else {
                WatchSyncingView(
                    title: syncingTitle,
                    refreshTitle: refreshTitle,
                    onRefresh: { channel.requestStateFromCounterpart() }
                )
            }
        }
    }
}

public struct WatchProRequiredView: View {
    private let title: LocalizedStringKey
    private let subtitle: LocalizedStringKey
    private let refreshTitle: LocalizedStringKey
    private let onRefresh: () -> Void

    public init(
        title: LocalizedStringKey = "Pro Required",
        subtitle: LocalizedStringKey = "Upgrade to Pro on your iPhone to unlock the Watch app.",
        refreshTitle: LocalizedStringKey = "Refresh",
        onRefresh: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.refreshTitle = refreshTitle
        self.onRefresh = onRefresh
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button(refreshTitle, action: onRefresh)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}

public struct WatchSyncingView: View {
    private let title: LocalizedStringKey
    private let refreshTitle: LocalizedStringKey
    private let onRefresh: () -> Void

    public init(
        title: LocalizedStringKey = "Syncing...",
        refreshTitle: LocalizedStringKey = "Refresh",
        onRefresh: @escaping () -> Void
    ) {
        self.title = title
        self.refreshTitle = refreshTitle
        self.onRefresh = onRefresh
    }

    public var body: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button(refreshTitle, action: onRefresh)
                .buttonStyle(.bordered)
        }
        .padding()
    }
}
