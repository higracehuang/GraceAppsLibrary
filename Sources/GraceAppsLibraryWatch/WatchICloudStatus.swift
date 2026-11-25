import CloudKit
import Foundation

public enum WatchICloudAvailability: Equatable, Sendable {
    case available
    case unavailable
    case restricted
    case temporarilyUnavailable
    case unknown
}

/// Opt-in iCloud status helper for Watch apps that use CloudKit / `NSUbiquitousKeyValueStore`.
public enum WatchICloudStatus {
    /// Fast, offline check for whether an iCloud account token is present on the device.
    public static var isSignedIn: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    /// Queries CloudKit account status asynchronously (for diagnostics / empty-state hints).
    public static func availability(containerIdentifier: String? = nil) async -> WatchICloudAvailability {
        let container = containerIdentifier.map { CKContainer(identifier: $0) } ?? CKContainer.default()
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                return .available
            case .noAccount:
                return .unavailable
            case .restricted:
                return .restricted
            case .temporarilyUnavailable:
                return .temporarilyUnavailable
            case .couldNotDetermine:
                return .unknown
            @unknown default:
                return .unknown
            }
        } catch {
            GraceWatchLogger.sync("CloudKit accountStatus failed: \(error.localizedDescription)", level: .warning)
            return isSignedIn ? .unknown : .unavailable
        }
    }
}
