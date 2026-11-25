//
//  UniversalAdCoordinator.swift
//  GraceAppsLibraryAdMob
//
//  Created by Grace Huang on 11/17/26.
//

#if canImport(UIKit)
import UIKit
@_exported import GoogleMobileAds
import GraceAppsLibrary

/// A protocol abstracting full-screen presentable ads (such as GADInterstitialAd).
@MainActor
public protocol UniversalPresentableAd: AnyObject {
    var fullScreenContentDelegate: FullScreenContentDelegate? { get set }
    func present(from rootViewController: UIViewController?)
}

extension InterstitialAd: UniversalPresentableAd {}

/// Centralized, production-grade Google Mobile Ads (AdMob) interstitial coordinator.
/// Encapsulates JIT preloading, 50-minute cache TTL hygiene, AdPacingEngine debouncing,
/// top view controller presentation, automated UI test mock presentation, and full-screen delegate events.
@MainActor
public final class UniversalAdCoordinator: NSObject, FullScreenContentDelegate, ObservableObject {
    public static let shared = UniversalAdCoordinator()

    #if DEBUG
    /// Allows enabling mock presentation programmatically in unit tests.
    public static var isMockPresentationEnabled: Bool = false
    #endif

    // MARK: - Published State

    /// Mapping of trigger identifiers (e.g. "fast_completed", "after_quiz", "default") to AdMob ad unit IDs.
    @Published public var adUnitMap: [String: String] = [:]

    /// Whether an ad is currently being presented to the user.
    @Published public private(set) var isShowingAd: Bool = false

    /// Whether an interstitial ad is actively being preloaded over the network.
    @Published public private(set) var isInterstitialLoading: Bool = false

    /// Read-only snapshot of cached interstitial ads by trigger.
    @Published public internal(set) var cachedAds: [String: UniversalPresentableAd] = [:]

    /// Mapping of rewarded ad trigger identifiers to AdMob ad unit IDs.
    @Published public private(set) var rewardedAdUnitMap: [String: String] = [:]

    /// Mapping of rewarded ad trigger identifiers to `FreeLimit` keys that receive earned credits.
    public private(set) var rewardedCreditTargets: [String: String] = [:]

    /// Whether at least one rewarded ad is currently loaded and ready to present.
    @Published public private(set) var isRewardedAdReady: Bool = false

    internal var cachedRewardedAds: [String: RewardedAd] = [:]
    internal var activeRewardedLoadingTriggers: Set<String> = []

    // MARK: - Internal State

    internal var adLoadDates: [String: Date] = [:]
    internal var activeLoadingTriggers: Set<String> = []
    internal var registeredTriggers: Set<String> = []
    internal var isSDKInitialized: Bool = false
    internal var activeDismissalCallback: (@MainActor (Bool) -> Void)?
    internal var activePresentingTrigger: String?
    internal var adLoader: ((String) async throws -> UniversalPresentableAd)?
    internal var topViewControllerResolver: (() -> UIViewController?)?
    private var foregroundObserver: NSObjectProtocol?

    public let pacing = AdPacingEngine.shared

    /// Formatted Google Mobile Ads SDK version string (e.g. "12.14.0" or "13.12.0").
    public var sdkVersion: String {
        let v = MobileAds.shared.versionNumber
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    public override init() {
        super.init()
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshAllRegisteredTriggers()
            }
        }
    }

    deinit {
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Configuration & Setup

    /// Configures the ad unit mapping and optional Pro entitlement check in one line.
    /// - Parameters:
    ///   - adUnits: Dictionary mapping trigger names to AdMob Ad Unit IDs.
    ///   - defaultUnitID: Optional fallback ad unit ID registered under "default".
    ///   - isPro: Optional closure returning true if the user has an active Pro / Ad-Free entitlement.
    public func configure(
        adUnits: [String: String] = [:],
        defaultUnitID: String? = nil,
        isPro: (() -> Bool)? = nil
    ) {
        self.adUnitMap = adUnits
        for trigger in adUnits.keys where !trigger.isEmpty {
            self.registeredTriggers.insert(trigger)
        }
        if let defaultUnitID = defaultUnitID {
            self.adUnitMap["default"] = defaultUnitID
        }
        if let isPro = isPro {
            self.pacing.isProUser = isPro
        }
        GraceLogger.ads("Configured UniversalAdCoordinator with \(adUnits.count) ad units.", level: .info)
    }

    /// Initializes Google Mobile Ads SDK asynchronously and refreshes any registered triggers once ready.
    public func initialize(completion: ((InitializationStatus) -> Void)? = nil) {
        MobileAds.shared.start { [weak self] status in
            GraceLogger.ads("Google Mobile Ads initialized successfully.", level: .info)
            completion?(status)
            Task { @MainActor in
                guard let self = self else { return }
                self.isSDKInitialized = true
                await self.refreshAllRegisteredTriggers()
            }
        }
    }

    /// Registers an AdMob ad unit ID for a specific trigger.
    public func register(adUnitID: String, for trigger: String) {
        adUnitMap[trigger] = adUnitID
        if !trigger.isEmpty {
            registeredTriggers.insert(trigger)
        }
    }

    /// Registers the default AdMob ad unit ID used when a trigger has no explicit mapping.
    public func registerDefault(adUnitID: String) {
        adUnitMap["default"] = adUnitID
    }

    /// Resolves the ad unit ID for a trigger, falling back to "default" if unmapped.
    public func resolveAdUnitID(for trigger: String) -> String? {
        adUnitMap[trigger] ?? adUnitMap["default"]
    }

    /// Evaluates whether ads can be shown (user is not Pro and flow is not paywall-suppressed).
    public var canShowAds: Bool {
        !pacing.isProUser() && !pacing.isFlowPaywallSuppressed
    }

    /// Queries `AdPacingEngine` to determine if presentation is permitted for the given trigger.
    public func shouldShowAd(for trigger: String = "default") -> Bool {
        pacing.canPresentAd(for: trigger)
    }

    // MARK: - 50-Minute Cache TTL Hygiene

    /// Discards expired cached ad inventory (default: 50 minutes TTL) to prevent stale AdMob impressions.
    public func cleanExpiredAds() {
        let now = Date()
        let ttl = pacing.config.cacheTTL
        var expiredTriggers: [String] = []

        for (trigger, date) in adLoadDates {
            if now.timeIntervalSince(date) >= ttl {
                expiredTriggers.append(trigger)
            }
        }

        for trigger in expiredTriggers {
            cachedAds.removeValue(forKey: trigger)
            adLoadDates.removeValue(forKey: trigger)
            GraceLogger.ads("Discarded expired interstitial ad cache for trigger '\(trigger)' (TTL exceeded).", level: .info)
        }
    }

    /// Checks whether an ad is cached, unexpired, and ready to present for the given trigger.
    public func isAdReady(for trigger: String = "default") -> Bool {
        cleanExpiredAds()
        return cachedAds[trigger] != nil || (trigger != "default" && cachedAds["default"] != nil)
    }

    /// Clears all preloaded ads from cache (e.g. when user purchases Pro or resets session).
    public func clearAllAds() {
        cachedAds.removeAll()
        adLoadDates.removeAll()
        activeLoadingTriggers.removeAll()
        isShowingAd = false
        isInterstitialLoading = false
        GraceLogger.ads("Cleared all cached ads in UniversalAdCoordinator.", level: .info)
    }

    /// Resets per-session tracking in AdPacingEngine and clears cached ads.
    public func resetSession() {
        pacing.resetSession()
        clearAllAds()
        GraceLogger.ads("UniversalAdCoordinator: Session reset.", level: .info)
    }

    // MARK: - JIT Preloading (Zero Wasted Requests)

    /// Evaluates `AdPacingEngine` gatekeepers and preloads an ad JIT only if eligible.
    public func preloadJIT(for trigger: String = "default") async {
        if !trigger.isEmpty {
            registeredTriggers.insert(trigger)
        }
        cleanExpiredAds()

        let fresh = isAdReady(for: trigger)
        guard pacing.canPreloadAd(for: trigger, isCacheValid: fresh) else {
            return
        }

        guard let unitID = resolveAdUnitID(for: trigger) else {
            GraceLogger.ads("Preload skipped for '\(trigger)': No ad unit ID configured in adUnitMap.", level: .warning)
            return
        }

        guard !activeLoadingTriggers.contains(trigger) else {
            GraceLogger.ads("Preload skipped for '\(trigger)': Load already in-flight.", level: .info)
            return
        }

        activeLoadingTriggers.insert(trigger)
        isInterstitialLoading = true
        defer {
            activeLoadingTriggers.remove(trigger)
            isInterstitialLoading = !activeLoadingTriggers.isEmpty
        }

        do {
            let ad: UniversalPresentableAd
            if let loader = adLoader {
                ad = try await loader(unitID)
            } else {
                ad = try await InterstitialAd.load(with: unitID, request: Request())
            }
            ad.fullScreenContentDelegate = self
            self.cachedAds[trigger] = ad
            self.adLoadDates[trigger] = Date()
            GraceLogger.ads("Successfully preloaded interstitial ad for '\(trigger)'.", level: .success)
        } catch {
            GraceLogger.ads("Failed to preload interstitial ad for '\(trigger)': \(error.localizedDescription)", level: .error)
        }
    }

    /// Preloads all declared triggers of an enum conforming to `CaseIterable & RawRepresentable`.
    public func preloadAll<T: CaseIterable & RawRepresentable>(triggers: T.Type) where T.RawValue == String {
        for trigger in triggers.allCases {
            if !trigger.rawValue.isEmpty {
                registeredTriggers.insert(trigger.rawValue)
            }
            Task {
                await preloadJIT(for: trigger.rawValue)
            }
        }
    }

    /// Evicts any expired ads (older than 50-minute TTL) and preloads all registered triggers that are missing or expired.
    /// Automatically invoked after SDK initialization and whenever the app becomes active in the foreground.
    public func refreshAllRegisteredTriggers() async {
        cleanExpiredAds()
        let triggersToRefresh: Set<String>
        if !registeredTriggers.isEmpty {
            triggersToRefresh = registeredTriggers
        } else if adUnitMap["default"] != nil {
            triggersToRefresh = ["default"]
        } else {
            return
        }

        for trigger in triggersToRefresh {
            await preloadJIT(for: trigger)
        }
    }

    /// Legacy load method for backwards compatibility.
    public func loadAd() {
        Task {
            await preloadJIT(for: "default")
        }
    }

    // MARK: - Presentation

    /// Presents a cached interstitial ad for the specified trigger if approved by `AdPacingEngine`.
    /// - Note: Internal to GraceAppsLibraryAdMob. Client views should invoke ads via `UXFlowOrchestrator.shared.requestActions([UXAction.universalAd(trigger:)])`.
    @discardableResult
    internal func present(
        for trigger: String = "default",
        from viewController: UIViewController? = nil,
        completion: ((Bool) -> Void)? = nil
    ) -> Bool {
        if !trigger.isEmpty {
            registeredTriggers.insert(trigger)
        }
        cleanExpiredAds()

        #if DEBUG
        // Support automated UI test mock presentation flag
        if ProcessInfo.processInfo.arguments.contains("-MockAdPresentation") || UniversalAdCoordinator.isMockPresentationEnabled {
            guard pacing.canPresentAd(for: trigger) else {
                completion?(false)
                return false
            }
            guard let hostVC = viewController ?? UIApplication.getTopViewController() else {
                completion?(false)
                return false
            }

            self.isShowingAd = true
            pacing.recordAdPresented(for: trigger)

            let mockAdVC = MockInterstitialAdViewController { [weak self] in
                guard let self = self else { return }
                self.isShowingAd = false
                completion?(true)
            }

            if hostVC.isBeingDismissed || hostVC.presentedViewController?.isBeingDismissed == true {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                    guard let freshTop = self?.resolveTopViewController() else {
                        self?.isShowingAd = false
                        completion?(false)
                        return
                    }
                    freshTop.present(mockAdVC, animated: true)
                }
                return true
            }

            hostVC.present(mockAdVC, animated: true)
            return true
        }
        #endif

        guard pacing.canPresentAd(for: trigger) else {
            completion?(false)
            return false
        }

        let ad: UniversalPresentableAd?
        if let triggerAd = cachedAds.removeValue(forKey: trigger) {
            ad = triggerAd
            adLoadDates.removeValue(forKey: trigger)
        } else {
            ad = cachedAds.removeValue(forKey: "default")
            adLoadDates.removeValue(forKey: "default")
        }

        guard let ad = ad else {
            GraceLogger.ads("Presentation skipped for '\(trigger)': Ad was not ready in cache. Triggering background replenishment...", level: .warning)
            completion?(false)
            Task { @MainActor [weak self] in
                await self?.preloadJIT(for: trigger)
            }
            return false
        }

        guard let rootVC = viewController ?? resolveTopViewController() else {
            GraceLogger.ads("Presentation failed for '\(trigger)': Could not resolve top view controller.", level: .error)
            completion?(false)
            return false
        }

        self.activeDismissalCallback = completion
        self.activePresentingTrigger = trigger
        self.isShowingAd = true

        pacing.recordAdPresented(for: trigger)

        // Modal transition safety buffer: if currently dismissing a sheet, settle before presenting
        if rootVC.isBeingDismissed || rootVC.presentedViewController?.isBeingDismissed == true {
            GraceLogger.ads("Active view controller in transition. Settling before ad presentation...", level: .info)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                guard let self = self else { return }
                guard let freshTop = self.resolveTopViewController() else {
                    GraceLogger.ads("Failed to resolve settled top view controller for '\(trigger)'.", level: .error)
                    self.isShowingAd = false
                    let cb = self.activeDismissalCallback
                    self.activeDismissalCallback = nil
                    self.activePresentingTrigger = nil
                    cb?(false)
                    return
                }
                ad.present(from: freshTop)
            }
            return true
        }

        ad.present(from: rootVC)
        return true
    }

    /// Convenience presentation method with optional completion handler. Internal to GAL.
    internal func showAd(
        for trigger: String = "default",
        from viewController: UIViewController? = nil,
        completion: ((Bool) -> Void)? = nil
    ) {
        present(for: trigger, from: viewController, completion: completion)
    }

    /// Convenience overload supporting `showAd(trigger:)` parameter label. Internal to GAL.
    internal func showAd(
        trigger: String,
        from viewController: UIViewController? = nil,
        completion: ((Bool) -> Void)? = nil
    ) {
        present(for: trigger, from: viewController, completion: completion)
    }

    /// Convenience overload supporting `present(trigger:)` parameter label. Internal to GAL.
    @discardableResult
    internal func present(
        trigger: String,
        from viewController: UIViewController? = nil,
        completion: ((Bool) -> Void)? = nil
    ) -> Bool {
        present(for: trigger, from: viewController, completion: completion)
    }

    /// Legacy present with automatic preload on non-presentation. Internal to GAL.
    internal func presentAdAndLoadNextAd(shouldPresent: Bool) {
        guard shouldPresent else { return }
        present(for: "default") { [weak self] presented in
            if !presented {
                self?.loadAd()
            }
        }
    }

    private func resolveTopViewController() -> UIViewController? {
        topViewControllerResolver?() ?? UIApplication.getTopViewController()
    }

    // MARK: - GADFullScreenContentDelegate

    public nonisolated func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            GraceLogger.ads("AdMob interstitial recorded impression.", level: .info)
        }
    }

    public nonisolated func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            GraceLogger.ads("AdMob interstitial recorded click.", level: .info)
        }
    }

    public nonisolated func ad(
        _ ad: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        Task { @MainActor in
            GraceLogger.ads("AdMob interstitial failed to present: \(error.localizedDescription)", level: .error)
            self.isShowingAd = false
            let callback = self.activeDismissalCallback
            self.activeDismissalCallback = nil
            self.activePresentingTrigger = nil
            callback?(false)

            // Attempt replenishment
            await self.preloadJIT()
        }
    }

    public nonisolated func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            GraceLogger.ads("AdMob interstitial will present full screen content.", level: .info)
            self.isShowingAd = true
        }
    }

    public nonisolated func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            GraceLogger.ads("AdMob interstitial will dismiss full screen content.", level: .info)
        }
    }

    public nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            GraceLogger.ads("AdMob interstitial dismissed cleanly.", level: .info)
            self.isShowingAd = false
            let callback = self.activeDismissalCallback
            let trigger = self.activePresentingTrigger ?? "default"
            self.activeDismissalCallback = nil
            self.activePresentingTrigger = nil
            callback?(true)

            // Preload next fresh ad for future presentation
            await self.preloadJIT(for: trigger)
        }
    }
}

// MARK: - Generic RawRepresentable (Enum) Overloads

extension UniversalAdCoordinator {
    /// Preloads an interstitial ad Just-In-Time using any String-backed enum trigger.
    public func preloadJIT<T: RawRepresentable>(for trigger: T) async where T.RawValue == String {
        await preloadJIT(for: trigger.rawValue)
    }

    /// Fire-and-forget convenience overload for preloading an interstitial ad Just-In-Time using any String-backed enum trigger.
    public func preloadJIT<T: RawRepresentable>(trigger: T) where T.RawValue == String {
        Task {
            await preloadJIT(for: trigger.rawValue)
        }
    }

    /// Evaluates policy and presents an interstitial ad using any String-backed enum trigger. Internal to GAL.
    @discardableResult
    internal func present<T: RawRepresentable>(
        for trigger: T,
        from viewController: UIViewController? = nil,
        completion: ((Bool) -> Void)? = nil
    ) -> Bool where T.RawValue == String {
        present(for: trigger.rawValue, from: viewController, completion: completion)
    }

    /// Evaluates policy and presents an interstitial ad using any String-backed enum trigger. Internal to GAL.
    @discardableResult
    internal func present<T: RawRepresentable>(
        trigger: T,
        from viewController: UIViewController? = nil,
        completion: ((Bool) -> Void)? = nil
    ) -> Bool where T.RawValue == String {
        present(for: trigger.rawValue, from: viewController, completion: completion)
    }

    /// Convenience presentation method using any String-backed enum trigger. Internal to GAL.
    internal func showAd<T: RawRepresentable>(
        for trigger: T,
        from viewController: UIViewController? = nil,
        completion: ((Bool) -> Void)? = nil
    ) where T.RawValue == String {
        showAd(for: trigger.rawValue, from: viewController, completion: completion)
    }

    /// Convenience presentation method using any String-backed enum trigger with `trigger:` label. Internal to GAL.
    internal func showAd<T: RawRepresentable>(
        trigger: T,
        from viewController: UIViewController? = nil,
        completion: ((Bool) -> Void)? = nil
    ) where T.RawValue == String {
        showAd(for: trigger.rawValue, from: viewController, completion: completion)
    }

    /// Evaluates whether an ad can be presented using any String-backed enum trigger.
    public func shouldShowAd<T: RawRepresentable>(for trigger: T) -> Bool where T.RawValue == String {
        shouldShowAd(for: trigger.rawValue)
    }

    /// Checks whether a cached ad is ready using any String-backed enum trigger.
    public func isAdReady<T: RawRepresentable>(for trigger: T) -> Bool where T.RawValue == String {
        isAdReady(for: trigger.rawValue)
    }

    // MARK: - Rewarded Ads

    /// Configures rewarded ad unit IDs using a String-backed enum trigger.
    public func configureRewarded<T: Hashable & RawRepresentable>(
        adUnits: [T: String],
        isPro: (() -> Bool)? = nil
    ) where T.RawValue == String {
        var mapped: [String: String] = [:]
        for (key, value) in adUnits {
            mapped[key.rawValue] = value
        }
        self.rewardedAdUnitMap = mapped
        self.rewardedCreditTargets = [:]
        if let isPro = isPro {
            self.pacing.isProUser = isPro
        }
        GraceLogger.ads("Configured UniversalAdCoordinator with \(mapped.count) rewarded ad units.", level: .info)
    }

    /// Configures rewarded ad unit IDs and maps triggers to `FreeLimit` keys that automatically receive earned credits.
    public func configureRewarded<T: Hashable & RawRepresentable, L: RawRepresentable>(
        adUnits: [T: String],
        grantsCreditsFor: [T: L],
        isPro: (() -> Bool)? = nil
    ) where T.RawValue == String, L.RawValue == String {
        configureRewarded(adUnits: adUnits, isPro: isPro)
        var targets: [String: String] = [:]
        for (trigger, limitKey) in grantsCreditsFor {
            targets[trigger.rawValue] = limitKey.rawValue
        }
        self.rewardedCreditTargets = targets
    }

    /// Returns whether a rewarded ad is loaded and ready for the given enum trigger.
    public func isRewardedAdReady<T: RawRepresentable>(for trigger: T) -> Bool where T.RawValue == String {
        cachedRewardedAds[trigger.rawValue] != nil
    }

    /// Preloads a rewarded ad for the given enum trigger if the user is not Pro.
    public func loadRewardedAd<T: RawRepresentable>(for trigger: T) async where T.RawValue == String {
        let key = trigger.rawValue
        guard canShowAds else { return }
        guard cachedRewardedAds[key] == nil, !activeRewardedLoadingTriggers.contains(key) else { return }
        guard let unitID = rewardedAdUnitMap[key], !unitID.isEmpty else {
            GraceLogger.ads("No rewarded ad unit ID registered for trigger '\(key)'.", level: .warning)
            return
        }

        activeRewardedLoadingTriggers.insert(key)
        defer { activeRewardedLoadingTriggers.remove(key) }

        do {
            let ad = try await RewardedAd.load(with: unitID, request: Request())
            ad.fullScreenContentDelegate = self
            cachedRewardedAds[key] = ad
            isRewardedAdReady = !cachedRewardedAds.isEmpty
            GraceLogger.ads("Loaded rewarded ad for trigger '\(key)'.", level: .info)
        } catch {
            GraceLogger.ads("Failed to load rewarded ad for '\(key)': \(error.localizedDescription)", level: .error)
        }
    }

    /// Presents a cached rewarded ad for the given enum trigger, automatically granting credits to any configured `FreeLimit` key and invoking optional `onReward`.
    @discardableResult
    public func presentRewardedAd<T: RawRepresentable>(
        for trigger: T,
        from viewController: UIViewController? = nil,
        onReward: ((Int) -> Void)? = nil
    ) -> Bool where T.RawValue == String {
        let key = trigger.rawValue
        guard canShowAds else { return false }
        guard let ad = cachedRewardedAds.removeValue(forKey: key) else {
            GraceLogger.ads("Rewarded ad not ready for trigger '\(key)'.", level: .warning)
            isRewardedAdReady = !cachedRewardedAds.isEmpty
            return false
        }
        isRewardedAdReady = !cachedRewardedAds.isEmpty
        guard let hostVC = viewController ?? resolveTopViewController() else {
            GraceLogger.ads("Could not find host view controller for rewarded ad '\(key)'.", level: .error)
            return false
        }

        isShowingAd = true
        ad.present(from: hostVC) { [weak self] in
            let amount = Int(truncating: ad.adReward.amount)
            GraceLogger.ads("Rewarded ad granted reward: \(amount) for '\(key)'.", level: .info)
            if let limitKey = self?.rewardedCreditTargets[key] {
                FreeLimitBonusStore.shared.addCredits(amount, for: limitKey)
            }
            onReward?(amount)
        }
        return true
    }
}

// MARK: - UXAction Integration

extension UXAction {
    /// Creates a UXAction configured to present an interstitial ad through `UniversalAdCoordinator`.
    @MainActor
    public static func universalAd(
        id: UXActionID = .interstitialAd,
        trigger: String = "default",
        tags: Set<UXTag> = [.ad],
        coordinator: UniversalAdCoordinator = .shared
    ) -> UXAction {
        UXAction.ad(id: id, tags: tags) { completion in
            coordinator.present(for: trigger) { wasPresented in
                completion(wasPresented)
            }
        }
    }

    /// Creates a UXAction configured to present an interstitial ad using any String-backed enum trigger.
    @MainActor
    public static func universalAd<T: RawRepresentable>(
        id: UXActionID = .interstitialAd,
        trigger: T,
        tags: Set<UXTag> = [.ad],
        coordinator: UniversalAdCoordinator = .shared
    ) -> UXAction where T.RawValue == String {
        universalAd(id: id, trigger: trigger.rawValue, tags: tags, coordinator: coordinator)
    }
}

/// Backwards compatibility typealias for legacy `AdCoordinator`.
public typealias AdCoordinator = UniversalAdCoordinator
#endif
