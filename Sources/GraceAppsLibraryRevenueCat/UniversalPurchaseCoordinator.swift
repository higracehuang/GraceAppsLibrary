import Foundation
import Combine
import SwiftUI
import GraceAppsLibrary
import RevenueCat
import RevenueCatUI

/// Centralized coordinator managing RevenueCat subscriptions, entitlements, debug 3-way overrides,
/// and automatic paywall/ad pacing synchronization across Grace Apps.
@MainActor
public final class UniversalPurchaseCoordinator: NSObject, ObservableObject {
    public static let shared = UniversalPurchaseCoordinator()

    public static let defaultOverrideStorageKey = "GraceApps_Debug_EntitlementOverride"

    // MARK: - Published State

    /// The effective Pro status (respects 3-way debug overrides in DEBUG builds).
    @Published public private(set) var isPro: Bool = false

    /// The raw purchase/entitlement status directly reported by the Store / RevenueCat.
    @Published public private(set) var storeIsPro: Bool = false

    /// The latest customer info retrieved from RevenueCat.
    @Published public private(set) var customerInfo: CustomerInfo? = nil

    /// Controls presenting the RevenueCat paywall sheet.
    @Published public var showPaywall: Bool = false

    /// An optional specific offering identifier to present in the paywall (useful for testing paywall variants).
    @Published public var selectedOfferingIdentifier: String? = nil

    #if DEBUG
    /// The active 3-way debug override: Automatic / Force Pro / Force Free.
    @Published public var debugOverride: DebugEntitlementOverride = .automatic {
        didSet {
            UserDefaults.standard.set(debugOverride.rawValue, forKey: overrideStorageKey)
            syncEffective()
        }
    }
    #endif

    // MARK: - Configuration Properties

    public private(set) var entitlementId: String = "pro"
    public private(set) var tierName: String = "Pro"
    public var syncedStorageKey: String? = nil
    public var overrideStorageKey: String = defaultOverrideStorageKey

    /// Custom closure to evaluate whether a user is entitled from `CustomerInfo`.
    /// When nil, defaults to checking `customerInfo.entitlements[entitlementId]?.isActive == true`.
    public var isEntitledEvaluator: ((CustomerInfo) -> Bool)? = nil

    /// Callback invoked whenever effective `isPro` status changes (e.g. to clear AdMob ad cache).
    public var onProStatusChanged: ((Bool) -> Void)? = nil

    private var customerInfoStreamTask: Task<Void, Never>? = nil

    private override init() {
        super.init()
        wirePacingEngines()
    }

    public func wirePacingEngines() {
        PaywallPacingEngine.shared.isProUser = { [weak self] in self?.isPro ?? false }
        AdPacingEngine.shared.isProUser = { [weak self] in self?.isPro ?? false }
    }

    // MARK: - Public Configuration

    /// Configures RevenueCat and wires up entitlement checking, storage synchronization, and pacing engines.
    public func configure(
        apiKey: String,
        entitlementId: String = "pro",
        tierName: String = "Pro",
        syncedStorageKey: String? = nil,
        isEntitledEvaluator: ((CustomerInfo) -> Bool)? = nil,
        onProStatusChanged: ((Bool) -> Void)? = nil
    ) {
        self.entitlementId = entitlementId
        self.tierName = tierName
        self.syncedStorageKey = syncedStorageKey
        self.isEntitledEvaluator = isEntitledEvaluator
        self.onProStatusChanged = onProStatusChanged

        // 1. Seed store status synchronously from cached storage so UI doesn't flicker on launch
        let args = ProcessInfo.processInfo.arguments
        let isMockOrReset = args.contains("-USE_MOCK_DATA") || args.contains("-RESET_USER_DEFAULTS") || args.contains("-FORCE_FREE")
        if let key = syncedStorageKey {
            if isMockOrReset && !args.contains("-FORCE_PRO") && !args.contains("-ForcePro") {
                self.storeIsPro = false
            } else {
                self.storeIsPro = UserDefaults.standard.bool(forKey: key)
            }
        }

        // 2. Load debug override from arguments or storage
        #if DEBUG
        self.initDebugOverride()
        #endif

        // 3. Connect to GAL pacing engines automatically
        PaywallPacingEngine.shared.isProUser = { [weak self] in self?.isPro ?? false }
        AdPacingEngine.shared.isProUser = { [weak self] in self?.isPro ?? false }

        // 4. Resolve initial effective state immediately
        self.syncEffective()

        // 5. Configure RevenueCat SDK
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .warn
        #endif

        Purchases.configure(withAPIKey: apiKey)
        Purchases.shared.delegate = self

        // 6. Refresh CustomerInfo asynchronously and listen to stream
        Task { [weak self] in
            await self?.refreshCustomerInfo()
        }

        customerInfoStreamTask?.cancel()
        customerInfoStreamTask = Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                guard let self = self else { break }
                self.handleCustomerInfoUpdated(info)
            }
        }
    }

    // MARK: - CustomerInfo Handling

    public func refreshCustomerInfo() async {
        guard Purchases.isConfigured else { return }
        do {
            let info = try await Purchases.shared.customerInfo()
            handleCustomerInfoUpdated(info)
        } catch {
            GraceLogger.paywall("Failed to fetch CustomerInfo: \(error.localizedDescription)", level: .error)
        }
    }

    private func handleCustomerInfoUpdated(_ info: CustomerInfo) {
        self.customerInfo = info
        let isEntitled: Bool
        if let customEvaluator = self.isEntitledEvaluator {
            isEntitled = customEvaluator(info)
        } else {
            isEntitled = info.entitlements[entitlementId]?.isActive == true
        }

        setStoreStatus(isEntitled)
    }

    /// Sets the store purchase status directly (useful for testing or fallback).
    public func setStoreStatus(_ purchased: Bool) {
        self.storeIsPro = purchased
        syncEffective()
    }

    /// Restores previously purchased transactions via RevenueCat.
    @discardableResult
    public func restorePurchases() async throws -> CustomerInfo {
        let info = try await Purchases.shared.restorePurchases()
        handleCustomerInfoUpdated(info)
        return info
    }

    /// Loads all available paywall offerings configured in RevenueCat.
    public func loadOfferings() async -> [Offering] {
        guard Purchases.isConfigured else { return [] }
        do {
            let offerings = try await Purchases.shared.offerings()
            return Array(offerings.all.values).sorted { $0.identifier < $1.identifier }
        } catch {
            GraceLogger.paywall("Failed to load offerings: \(error.localizedDescription)", level: .error)
            return []
        }
    }

    // MARK: - Effective Status Synchronization

    public func syncEffective() {
        #if DEBUG
        self.isPro = debugOverride.resolve(storeStatus: storeIsPro)
        #else
        self.isPro = storeIsPro
        #endif

        if let key = syncedStorageKey {
            let isEphemeral = ProcessInfo.processInfo.arguments.contains("-FORCE_PRO")
                || ProcessInfo.processInfo.arguments.contains("-ForcePro")
                || ProcessInfo.processInfo.arguments.contains("-FORCE_FREE")
                || ProcessInfo.processInfo.arguments.contains("-ForceFree")
            if !isEphemeral {
                UserDefaults.standard.set(self.isPro, forKey: key)
            }
        }

        onProStatusChanged?(self.isPro)
    }

    #if DEBUG
    private func initDebugOverride() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-ForcePro") || args.contains("-FORCE_PRO") || args.contains("-forcePro") {
            self._debugOverride = Published(wrappedValue: .forcePro)
        } else if args.contains("-ForceFree") || args.contains("-FORCE_FREE") || args.contains("-forceFree") || args.contains("-UI_TEST_FREE_TIER") {
            self._debugOverride = Published(wrappedValue: .forceFree)
        } else if args.contains("-USE_MOCK_DATA") || args.contains("-RESET_USER_DEFAULTS") {
            self._debugOverride = Published(wrappedValue: .automatic)
        } else if let saved = UserDefaults.standard.string(forKey: overrideStorageKey),
                  let parsed = DebugEntitlementOverride(rawValue: saved) {
            self._debugOverride = Published(wrappedValue: parsed)
        }
    }
    #endif
}

// MARK: - PurchasesDelegate

extension UniversalPurchaseCoordinator: PurchasesDelegate {
    nonisolated public func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor [weak self] in
            self?.handleCustomerInfoUpdated(customerInfo)
        }
    }
}
