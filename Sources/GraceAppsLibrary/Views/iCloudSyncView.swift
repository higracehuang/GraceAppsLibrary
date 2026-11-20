//
//  iCloudSyncView.swift
//  GraceAppsLibrary
//

import SwiftUI
import CoreData
import CloudKit

public struct SyncStatusPill: View {
    @ObservedObject var syncManager: CloudKitSyncManager

    public init(syncManager: CloudKitSyncManager) {
        self.syncManager = syncManager
    }

    public var body: some View {
        HStack(spacing: 5) {
            if syncManager.isSyncing {
                ProgressView()
                    .scaleEffect(0.65)
            } else {
                Circle()
                    .fill(syncManager.statusColor)
                    .frame(width: 7, height: 7)
            }

            Text(syncManager.statusPillText)
                .font(.caption.weight(.medium))
                .foregroundColor(syncManager.statusColor)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(syncManager.statusColor.opacity(0.12))
        .clipShape(Capsule())
    }
}

public struct iCloudSyncView: View {
    @ObservedObject private var syncManager = CloudKitSyncManager.shared

    private let descriptionText: LocalizedStringKey?
    private let dataSyncedDescription: LocalizedStringKey?
    private let faqSections: [FAQSection]?

    public init(
        description: LocalizedStringKey? = nil,
        dataSyncedDescription: LocalizedStringKey? = nil,
        faqSections: [FAQSection]? = nil
    ) {
        self.descriptionText = description
        self.dataSyncedDescription = dataSyncedDescription
        self.faqSections = faqSections
    }

    public var body: some View {
        Form {
            // MARK: - Hero Header Card
            Section {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [syncManager.statusColor.opacity(0.2), syncManager.statusColor.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 76, height: 76)

                        Image(systemName: syncManager.statusIconName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 38, height: 38)
                            .foregroundColor(syncManager.statusColor)
                    }
                    .padding(.top, 4)

                    VStack(spacing: 4) {
                        Text(LocalizedStringKey("icloud_sync.title"), bundle: .module)
                            .font(.title2.weight(.bold))
                        if let descriptionText {
                            Text(descriptionText)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                        } else {
                            Text(LocalizedStringKey("icloud_sync.hero_description"), bundle: .module)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                        }
                    }

                    SyncStatusPill(syncManager: syncManager)
                        .padding(.top, 2)
                        .padding(.bottom, 4)
                }
                .frame(maxWidth: .infinity)
                .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                .listRowBackground(Color.clear)
            }

            // MARK: - Error Banner (if any)
            if let error = syncManager.lastError {
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey("icloud_sync.issue_title"), bundle: .module)
                                .font(.headline)
                                .foregroundColor(.red)
                            Text(error)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // MARK: - Sync Status Rows
            Section {
                HStack {
                    Label {
                        Text(LocalizedStringKey("icloud_sync.row.account"), bundle: .module)
                    } icon: {
                        Image(systemName: "person.crop.circle")
                    }
                    Spacer()
                    HStack(spacing: 5) {
                        Image(systemName: syncManager.accountStatusIconName)
                            .foregroundColor(syncManager.accountStatusColor)
                        Text(syncManager.accountStatusTitle)
                            .foregroundColor(.secondary)
                    }
                }

                HStack {
                    Label {
                        Text(LocalizedStringKey("icloud_sync.row.last_synced"), bundle: .module)
                    } icon: {
                        Image(systemName: "clock")
                    }
                    Spacer()
                    if syncManager.isSyncing {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text(syncManager.syncProgressMessage)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text(syncManager.lastSyncFormatted)
                            .foregroundColor(.secondary)
                    }
                }

                HStack {
                    Label {
                        Text(LocalizedStringKey("icloud_sync.row.availability"), bundle: .module)
                    } icon: {
                        Image(systemName: "laptopcomputer.and.iphone")
                    }
                    Spacer()
                    Text(LocalizedStringKey("icloud_sync.row.all_devices"), bundle: .module)
                        .foregroundColor(.secondary)
                }

                if let dataSyncedDescription {
                    HStack {
                        Label {
                            Text(LocalizedStringKey("icloud_sync.row.data_synced"), bundle: .module)
                        } icon: {
                            Image(systemName: "tray.2")
                        }
                        Spacer()
                        Text(dataSyncedDescription)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text(LocalizedStringKey("icloud_sync.status_header"), bundle: .module)
            }

            // MARK: - Action Section
            Section {
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    Task {
                        await syncManager.triggerManualSync()
                    }
                } label: {
                    HStack {
                        Spacer()
                        if syncManager.isSyncing {
                            ProgressView()
                                .tint(.white)
                                .padding(.trailing, 4)
                            Text(LocalizedStringKey("icloud_sync.button.syncing"), bundle: .module)
                                .font(.headline)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.headline)
                            Text(LocalizedStringKey(syncManager.lastError != nil ? "icloud_sync.button.retry" : "icloud_sync.button.sync_now"), bundle: .module)
                                .font(.headline)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .disabled(syncManager.isSyncing || syncManager.accountStatus == .noAccount)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            } footer: {
                Text(LocalizedStringKey("icloud_sync.manual_sync_footer"), bundle: .module)
                    .font(.footnote)
            }

            // MARK: - FAQ / Help
            if let faqSections, !faqSections.isEmpty {
                Section {
                    FAQNavigationView(sections: faqSections)
                } footer: {
                    Text(LocalizedStringKey("icloud_sync.faq_footer"), bundle: .module)
                }
            }
        }
        .navigationTitle(Text(LocalizedStringKey("icloud_sync.title"), bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await syncManager.triggerManualSync()
        }
    }
}
