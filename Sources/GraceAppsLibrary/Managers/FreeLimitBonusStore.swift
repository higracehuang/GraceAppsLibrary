import Foundation

/// Shared persisted store for bonus free-tier credits (e.g. granted by rewarded ads).
public final class FreeLimitBonusStore: @unchecked Sendable {
    public static let shared = FreeLimitBonusStore()
    public static let didChangeNotification = Notification.Name("GraceApps_FreeLimitBonusStore_DidChange")

    private init() {}

    private func storageKey(for key: String) -> String {
        "GraceApps_FreeLimit_Credits_\(key)"
    }

    public func credits(for key: String) -> Int {
        UserDefaults.standard.integer(forKey: storageKey(for: key))
    }

    public func addCredits(_ amount: Int, for key: String) {
        let updated = credits(for: key) + amount
        UserDefaults.standard.set(updated, forKey: storageKey(for: key))
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    public func resetCredits(for key: String) {
        UserDefaults.standard.set(0, forKey: storageKey(for: key))
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }
}
