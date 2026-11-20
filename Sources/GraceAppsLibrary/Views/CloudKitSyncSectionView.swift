//
//  CloudKitSyncSectionView.swift
//  GraceAppsLibrary
//

import SwiftUI

public struct CloudKitSyncSectionView: View {
    @ObservedObject private var syncManager = CloudKitSyncManager.shared

    private let subtitle: LocalizedStringKey?
    private let descriptionText: LocalizedStringKey?
    private let dataSyncedDescription: LocalizedStringKey?
    private let faqSections: [FAQSection]?

    public init(
        subtitle: LocalizedStringKey? = nil,
        description: LocalizedStringKey? = nil,
        dataSyncedDescription: LocalizedStringKey? = nil,
        faqSections: [FAQSection]? = nil
    ) {
        self.subtitle = subtitle
        self.descriptionText = description
        self.dataSyncedDescription = dataSyncedDescription
        self.faqSections = faqSections
    }

    public var body: some View {
        Section {
            NavigationLink(
                destination: iCloudSyncView(
                    description: descriptionText,
                    dataSyncedDescription: dataSyncedDescription,
                    faqSections: faqSections
                )
            ) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(syncManager.statusColor.opacity(0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: syncManager.statusIconName)
                            .foregroundColor(syncManager.statusColor)
                            .font(.system(size: 15, weight: .semibold))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(LocalizedStringKey("icloud_sync.title"), bundle: .module)
                            .font(.body)
                        Text(syncManager.statusSubtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    SyncStatusPill(syncManager: syncManager)
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text(LocalizedStringKey("icloud_sync.section_header"), bundle: .module)
        } footer: {
            if let subtitle {
                Text(subtitle)
            } else {
                Text(LocalizedStringKey("icloud_sync.section_footer"), bundle: .module)
            }
        }
    }
}
