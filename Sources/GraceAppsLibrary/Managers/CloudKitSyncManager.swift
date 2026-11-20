//
//  CloudKitSyncManager.swift
//  GraceAppsLibrary
//

import Foundation
import CoreData
import CloudKit
import Combine
import SwiftUI
import UIKit

@MainActor
public final class CloudKitSyncManager: ObservableObject {
    public static let shared = CloudKitSyncManager()

    @Published public var accountStatus: CKAccountStatus = .couldNotDetermine
    @Published public var isSyncing: Bool = false
    @Published public var lastSuccessfulSync: Date? {
        didSet {
            if let date = lastSuccessfulSync {
                UserDefaults.standard.set(date.timeIntervalSince1970, forKey: Self.lastSyncStorageKey)
            }
        }
    }
    @Published public var lastError: String?
    @Published public var syncProgressMessage: String

    private static let lastSyncStorageKey = "gal_lastSuccessfulCloudKitSync"

    private var cancellables = Set<AnyCancellable>()
    private var containerIdentifier: String?
    private var ckContainer: CKContainer?
    private var onManualSync: (() -> Void)?

    private init() {
        self.syncProgressMessage = Self.localized("icloud_sync.syncing")

        let savedTimestamp = UserDefaults.standard.double(forKey: Self.lastSyncStorageKey)
        if savedTimestamp > 0 {
            self.lastSuccessfulSync = Date(timeIntervalSince1970: savedTimestamp)
        }

        setupNotificationObservers()
        setupPeriodicRefresh()
    }

    /// Configures the CloudKit container identifier and optional manual-sync hook for the host app.
    public func configure(containerIdentifier: String, onManualSync: (() -> Void)? = nil) {
        self.containerIdentifier = containerIdentifier
        self.onManualSync = onManualSync
        guard !Self.isRunningInTestsOrPreviews else { return }
        self.ckContainer = CKContainer(identifier: containerIdentifier)
        Task {
            await checkAccountStatus()
        }
    }

    private static var isRunningInTestsOrPreviews: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    // MARK: - Periodic Refresh for Relative Timestamps

    private func setupPeriodicRefresh() {
        Timer.publish(every: 15, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Notification Observers

    private func setupNotificationObservers() {
        NotificationCenter.default.publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleCloudKitContainerEvent(notification)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .CKAccountChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.checkAccountStatus()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.checkAccountStatus()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Event Handling

    private func handleCloudKitContainerEvent(_ notification: Notification) {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else {
            return
        }

        let isFinished = event.endDate != nil

        if !isFinished {
            if event.type == .import || event.type == .export {
                isSyncing = true
                syncProgressMessage = event.type == .import
                    ? Self.localized("icloud_sync.downloading")
                    : Self.localized("icloud_sync.uploading")
            }
        } else {
            if event.type == .import || event.type == .export {
                isSyncing = false
                if event.succeeded {
                    lastSuccessfulSync = event.endDate ?? Date()
                    lastError = nil
                    GraceLogger.log("CloudKit sync event (\(event.type)) succeeded.", level: .success)
                } else if let error = event.error {
                    lastError = friendlyErrorMessage(for: error)
                    GraceLogger.log("CloudKit sync event (\(event.type)) failed: \(error.localizedDescription)", level: .error)
                }
            } else if event.type == .setup, let error = event.error {
                GraceLogger.log("CloudKit setup notice: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Account Status

    public func checkAccountStatus() async {
        guard !Self.isRunningInTestsOrPreviews else { return }
        let container: CKContainer
        if let configured = ckContainer {
            container = configured
        } else if let bundleID = Bundle.main.bundleIdentifier {
            let inferred = CKContainer(identifier: "iCloud.\(bundleID)")
            self.ckContainer = inferred
            container = inferred
        } else {
            return
        }

        do {
            let status = try await container.accountStatus()
            self.accountStatus = status
            let signedOutText = Self.localized("icloud_sync.error.not_signed_in_detail")
            if status == .noAccount {
                self.lastError = signedOutText
            } else if status == .available, lastError == signedOutText {
                self.lastError = nil
            }
            GraceLogger.log("iCloud account status: \(accountStatusTitle)")
        } catch {
            if let defaultStatus = try? await CKContainer.default().accountStatus() {
                self.accountStatus = defaultStatus
            } else {
                self.accountStatus = .couldNotDetermine
                self.lastError = error.localizedDescription
            }
            GraceLogger.log("Failed to check iCloud account status: \(error.localizedDescription)", level: .error)
        }
    }

    // MARK: - Manual Sync / Retry

    public func triggerManualSync() async {
        guard !isSyncing else { return }

        isSyncing = true
        syncProgressMessage = Self.localized("icloud_sync.checking")
        lastError = nil

        await checkAccountStatus()

        guard accountStatus == .available else {
            isSyncing = false
            lastError = accountStatusErrorMessage
            return
        }

        syncProgressMessage = Self.localized("icloud_sync.syncing_changes")
        onManualSync?()

        try? await Task.sleep(nanoseconds: 1_500_000_000)

        if isSyncing {
            isSyncing = false
            if lastError == nil {
                lastSuccessfulSync = Date()
            }
        }
    }

    // MARK: - UI Presentation Helpers

    public var accountStatusTitle: String {
        switch accountStatus {
        case .available:
            return Self.localized("icloud_sync.account.available")
        case .noAccount:
            return Self.localized("icloud_sync.account.no_account")
        case .restricted:
            return Self.localized("icloud_sync.account.restricted")
        case .couldNotDetermine:
            return Self.localized("icloud_sync.account.checking")
        case .temporarilyUnavailable:
            return Self.localized("icloud_sync.account.unavailable")
        @unknown default:
            return Self.localized("icloud_sync.account.unknown")
        }
    }

    public var accountStatusIconName: String {
        switch accountStatus {
        case .available:
            return "checkmark.circle.fill"
        case .noAccount:
            return "exclamationmark.triangle.fill"
        case .restricted:
            return "lock.fill"
        case .couldNotDetermine:
            return "questionmark.circle.fill"
        case .temporarilyUnavailable:
            return "exclamationmark.triangle.fill"
        @unknown default:
            return "questionmark.circle.fill"
        }
    }

    public var accountStatusColor: Color {
        switch accountStatus {
        case .available:
            return .green
        case .noAccount:
            return .red
        case .restricted, .temporarilyUnavailable:
            return .orange
        case .couldNotDetermine:
            return .secondary
        @unknown default:
            return .secondary
        }
    }

    public var statusColor: Color {
        if isSyncing {
            return .blue
        }
        if lastError != nil {
            return .red
        }
        switch accountStatus {
        case .available:
            return .green
        case .noAccount, .restricted, .temporarilyUnavailable:
            return .orange
        case .couldNotDetermine:
            return .secondary
        @unknown default:
            return .secondary
        }
    }

    public var statusIconName: String {
        if isSyncing {
            return "arrow.triangle.2.circlepath"
        }
        if lastError != nil {
            return "exclamationmark.triangle.fill"
        }
        switch accountStatus {
        case .available:
            return "icloud.fill"
        case .noAccount:
            return "icloud.slash.fill"
        case .restricted:
            return "lock.icloud.fill"
        case .temporarilyUnavailable, .couldNotDetermine:
            return "exclamationmark.icloud.fill"
        @unknown default:
            return "icloud"
        }
    }

    public var statusSubtitle: String {
        if isSyncing {
            return syncProgressMessage
        }
        if let error = lastError {
            if accountStatus == .noAccount {
                return Self.localized("icloud_sync.subtitle.not_signed_in")
            }
            return String(format: Self.localized("icloud_sync.subtitle.issue %@"), error)
        }
        if accountStatus == .noAccount {
            return Self.localized("icloud_sync.subtitle.sign_in_prompt")
        }
        if lastSuccessfulSync != nil {
            return String(format: Self.localized("icloud_sync.subtitle.up_to_date %@"), lastSyncFormatted)
        }
        return Self.localized("icloud_sync.subtitle.ready")
    }

    public var statusPillText: String {
        if isSyncing {
            return Self.localized("icloud_sync.pill.syncing")
        }
        if lastError != nil {
            return Self.localized("icloud_sync.pill.issue")
        }
        switch accountStatus {
        case .available:
            return Self.localized("icloud_sync.pill.up_to_date")
        case .noAccount:
            return Self.localized("icloud_sync.pill.signed_out")
        case .restricted:
            return Self.localized("icloud_sync.pill.restricted")
        case .temporarilyUnavailable:
            return Self.localized("icloud_sync.pill.unavailable")
        case .couldNotDetermine:
            return Self.localized("icloud_sync.pill.checking")
        @unknown default:
            return Self.localized("icloud_sync.pill.offline")
        }
    }

    public var accountStatusErrorMessage: String {
        switch accountStatus {
        case .noAccount:
            return Self.localized("icloud_sync.account_error.no_account")
        case .restricted:
            return Self.localized("icloud_sync.account_error.restricted")
        case .temporarilyUnavailable:
            return Self.localized("icloud_sync.account_error.unavailable")
        case .couldNotDetermine:
            return Self.localized("icloud_sync.account_error.could_not_determine")
        case .available:
            return ""
        @unknown default:
            return Self.localized("icloud_sync.account_error.unknown")
        }
    }

    public var lastSyncFormatted: String {
        guard let lastSync = lastSuccessfulSync else {
            return Self.localized("icloud_sync.last_sync.never")
        }

        let interval = Date().timeIntervalSince(lastSync)
        if interval < 45 {
            return Self.localized("icloud_sync.last_sync.just_now")
        } else if interval < 90 {
            return Self.localized("icloud_sync.last_sync.one_min_ago")
        } else if interval < 3600 {
            let minutes = max(1, Int(interval / 60))
            return String(format: Self.localized("icloud_sync.last_sync.mins_ago %lld"), Int64(minutes))
        }

        let formatter = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(lastSync) {
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            return String(format: Self.localized("icloud_sync.last_sync.today_at %@"), formatter.string(from: lastSync))
        } else if calendar.isDateInYesterday(lastSync) {
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            return String(format: Self.localized("icloud_sync.last_sync.yesterday_at %@"), formatter.string(from: lastSync))
        } else {
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: lastSync)
        }
    }

    public func friendlyErrorMessage(for error: Error) -> String {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .networkUnavailable, .networkFailure:
                return Self.localized("icloud_sync.error.network")
            case .notAuthenticated:
                return Self.localized("icloud_sync.error.not_authenticated")
            case .quotaExceeded:
                return Self.localized("icloud_sync.error.quota_exceeded")
            case .serviceUnavailable:
                return Self.localized("icloud_sync.error.service_unavailable")
            case .requestRateLimited:
                return Self.localized("icloud_sync.error.rate_limited")
            case .zoneNotFound, .userDeletedZone:
                return Self.localized("icloud_sync.error.zone_reset")
            default:
                return ckError.localizedDescription
            }
        }
        return error.localizedDescription
    }

    private static func localized(_ key: String) -> String {
        NSLocalizedString(key, bundle: .module, comment: "")
    }
}
