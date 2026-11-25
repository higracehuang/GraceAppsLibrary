import Foundation

/// Standard Pro-gated envelope pushed from iOS to Watch via `WatchSyncChannel`.
public struct WatchEntitlementEnvelope<Payload: Codable & Equatable>: Codable, Equatable {
    public let isPro: Bool
    public let updatedAt: Date
    public let payload: Payload

    public init(isPro: Bool, updatedAt: Date = Date(), payload: Payload) {
        self.isPro = isPro
        self.updatedAt = updatedAt
        self.payload = payload
    }
}
