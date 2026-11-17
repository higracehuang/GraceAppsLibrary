//
//  UniversalAdCoordinator.swift
//  GraceAppsLibraryAdMob
//
//  Created by Grace Huang on 11/17/26.
//

#if canImport(UIKit)
import UIKit
import GoogleMobileAds
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

    // MARK: - Internal State

    internal var adLoadDates: [String: Date] = [:]
    internal var activeLoadingTriggers: Set<String> = []
    internal var activeDismissalCallback: (@MainActor (Bool) -> Void)?
    internal var activePresentingTrigger: String?
    internal var adLoader: ((String) async throws -> UniversalPresentableAd)?
    internal var topViewControllerResolver: (() -> UIViewController?)?

    public let pacing = AdPacingEngine.shared

    public override init() {
        super.init()
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
        if let defaultUnitID = defaultUnitID {
            self.adUnitMap["default"] = defaultUnitID
        }
        if let isPro = isPro {
            self.pacing.isProUser = isPro
        }
        GraceLogger.ads("Configured UniversalAdCoordinator with \(adUnits.count) ad units.", level: .info)
    }

    /// Initializes Google Mobile Ads SDK asynchronously and updates pacing.
    public func initialize(completion: ((InitializationStatus) -> Void)? = nil) {
        MobileAds.shared.start { status in
            GraceLogger.ads("Google Mobile Ads initialized successfully.", level: .info)
            completion?(status)
        }
    }

    /// Registers an AdMob ad unit ID for a specific trigger.
    public func register(adUnitID: String, for trigger: String) {
        adUnitMap[trigger] = adUnitID
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

    // MARK: - JIT Preloading (Zero Wasted Requests)

    /// Evaluates `AdPacingEngine` gatekeepers and preloads an ad JIT only if eligible.
    public func preloadJIT(for trigger: String = "default") async {
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
            Task {
                await preloadJIT(for: trigger.rawValue)
            }
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
    /// - Parameters:
    ///   - trigger: Trigger identifier (e.g. "fast_completed").
    ///   - viewController: Optional presenting UIViewController. If nil, automatically resolves the top-most visible controller.
    ///   - completion: Callback invoked with `true` when the ad finishes presentation, or `false` if suppressed/failed.
    /// - Returns: `true` if presentation was initiated; `false` if suppressed or not ready.
    @discardableResult
    public func present(
        for trigger: String = "default",
        from viewController: UIViewController? = nil,
        completion: ((Bool) -> Void)? = nil
    ) -> Bool {
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

        let ad = cachedAds.removeValue(forKey: trigger) ?? cachedAds.removeValue(forKey: "default")
        adLoadDates.removeValue(forKey: trigger)
        adLoadDates.removeValue(forKey: "default")

        guard let ad = ad else {
            GraceLogger.ads("Presentation skipped for '\(trigger)': Ad was not ready in cache.", level: .warning)
            completion?(false)
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

    /// Convenience presentation method with optional completion handler.
    public func showAd(
        for trigger: String = "default",
        from viewController: UIViewController? = nil,
        completion: ((Bool) -> Void)? = nil
    ) {
        present(for: trigger, from: viewController, completion: completion)
    }

    /// Convenience overload supporting `showAd(trigger:)` parameter label.
    public func showAd(
        trigger: String,
        from viewController: UIViewController? = nil,
        completion: ((Bool) -> Void)? = nil
    ) {
        present(for: trigger, from: viewController, completion: completion)
    }

    /// Convenience overload supporting `present(trigger:)` parameter label.
    @discardableResult
    public func present(
        trigger: String,
        from viewController: UIViewController? = nil,
        completion: ((Bool) -> Void)? = nil
    ) -> Bool {
        present(for: trigger, from: viewController, completion: completion)
    }

    /// Legacy present with automatic preload on non-presentation.
    public func presentAdAndLoadNextAd(shouldPresent: Bool) {
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

    /// Evaluates policy and presents an interstitial ad using any String-backed enum trigger.
    @discardableResult
    public func present<T: RawRepresentable>(
        for trigger: T,
        from viewController: UIViewController? = nil,
        completion: ((Bool) -> Void)? = nil
    ) -> Bool where T.RawValue == String {
        present(for: trigger.rawValue, from: viewController, completion: completion)
    }

    /// Evaluates policy and presents an interstitial ad using any String-backed enum trigger.
    @discardableResult
    public func present<T: RawRepresentable>(
        trigger: T,
        from viewController: UIViewController? = nil,
        completion: ((Bool) -> Void)? = nil
    ) -> Bool where T.RawValue == String {
        present(for: trigger.rawValue, from: viewController, completion: completion)
    }

    /// Convenience presentation method using any String-backed enum trigger.
    public func showAd<T: RawRepresentable>(
        for trigger: T,
        from viewController: UIViewController? = nil,
        completion: ((Bool) -> Void)? = nil
    ) where T.RawValue == String {
        showAd(for: trigger.rawValue, from: viewController, completion: completion)
    }

    /// Convenience presentation method using any String-backed enum trigger with `trigger:` label.
    public func showAd<T: RawRepresentable>(
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
