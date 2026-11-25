import Combine
import Foundation
import WatchConnectivity
import WidgetKit
#if os(iOS)
import UIKit
#endif

/// Generic, testable `WCSession` state & action channel shared between iOS and watchOS targets.
///
/// - Important: Call `activate()` early in app startup (e.g. `App.init` or `AppDelegate`)
///   so background `WCSession` wakeups always have a delegate attached.
public final class WatchSyncChannel<State: Codable & Equatable>: NSObject, ObservableObject, WCSessionDelegate {
    @MainActor @Published public private(set) var state: State?
    @MainActor @Published public private(set) var isActivated: Bool = false
    @MainActor @Published public private(set) var isReachable: Bool = false
    @MainActor @Published public private(set) var isWatchAppInstalled: Bool = false

    /// Called on the main actor when an action payload (not a state snapshot) arrives from the counterpart.
    public var onReceiveAction: (@MainActor (_ payload: [String: Any], _ replyHandler: (([String: Any]) -> Void)?) -> Void)?

    /// Called on the main actor once `WCSession` finishes activating.
    public var onSessionActivated: (@MainActor () -> Void)?

    public let stateKey: String
    public let requestStateKey: String
    public let cacheKey: String
    public let reloadWidgetsOnUpdate: Bool
    public let autoRequestStateOnActivate: Bool

    private let appGroupDefaults: UserDefaults?
    private let session: WatchSessionProtocol?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var lastSentState: State?
    private var pendingState: State?
    private var pendingStateRequest = false

    public init(
        session: WatchSessionProtocol? = WCSession.isSupported() ? WCSession.default : nil,
        stateKey: String = "gal_watch_state",
        requestStateKey: String = "gal_request_state",
        appGroupSuiteName: String? = nil,
        cacheKey: String = "gal_watch_cached_state",
        reloadWidgetsOnUpdate: Bool = true,
        autoRequestStateOnActivate: Bool = true
    ) {
        self.session = session
        self.stateKey = stateKey
        self.requestStateKey = requestStateKey
        self.appGroupDefaults = appGroupSuiteName.flatMap { UserDefaults(suiteName: $0) }
        self.cacheKey = cacheKey
        self.reloadWidgetsOnUpdate = reloadWidgetsOnUpdate
        self.autoRequestStateOnActivate = autoRequestStateOnActivate
        super.init()

        self.session?.delegate = self
        loadCachedStateIfAvailable()
    }

    // MARK: - Lifecycle

    public func activate() {
        guard let session else {
            GraceWatchLogger.session("WCSession is not supported on this device", level: .warning)
            return
        }
        session.delegate = self
        session.activate()
    }

    // MARK: - State Publishing (iOS -> Watch, or local cache)

    @MainActor
    public func pushState(_ newState: State, force: Bool = false) {
        if !force, newState == lastSentState {
            return
        }

        applyLocalState(newState)

        guard let session else { return }
        guard session.activationState == .activated else {
            pendingState = newState
            GraceWatchLogger.sync("Queued state push until WCSession activates")
            return
        }

        guard canCommunicateWithCounterpart(session) else {
            pendingState = newState
            return
        }

        pendingState = nil
        sendEncodedState(newState, over: session)
    }

    /// Updates local published state & App Group cache without transmitting over `WCSession`
    /// (useful for optimistic Watch UI updates).
    @MainActor
    public func updateLocalState(_ newState: State) {
        applyLocalState(newState)
    }

    // MARK: - Actions & Requests

    public func requestStateFromCounterpart() {
        guard let session, session.activationState == .activated else {
            pendingStateRequest = true
            GraceWatchLogger.sync("Queued state request until WCSession activates")
            return
        }

        guard canCommunicateWithCounterpart(session) else { return }

        pendingStateRequest = false
        let payload: [String: Any] = [requestStateKey: true]
        if session.isReachable {
            session.sendMessage(payload, replyHandler: { [weak self] reply in
                self?.handleIncomingPayload(reply, replyHandler: nil)
            }, errorHandler: { [weak self] error in
                GraceWatchLogger.sync("State request failed (\(error.localizedDescription)); falling back to transferUserInfo", level: .warning)
                self?.queueStateRequestTransferIfNeeded(payload, over: session)
            })
        } else {
            queueStateRequestTransferIfNeeded(payload, over: session)
        }
    }

    public func sendAction(_ payload: [String: Any], fallbackToUserInfo: Bool = true) {
        guard let session, session.activationState == .activated else {
            GraceWatchLogger.sync("Cannot send action: WCSession not activated", level: .warning)
            return
        }

        guard canCommunicateWithCounterpart(session) else { return }

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                GraceWatchLogger.sync("sendMessage failed: \(error.localizedDescription)", level: .warning)
                if fallbackToUserInfo {
                    _ = session.transferUserInfo(payload)
                }
            }
        } else if fallbackToUserInfo {
            _ = session.transferUserInfo(payload)
        }
    }

    // MARK: - Internal Helpers

    /// Synchronously reads the last cached state from App Group `UserDefaults`, if configured.
    public var cachedState: State? {
        guard let data = appGroupDefaults?.data(forKey: cacheKey) else { return nil }
        return try? decoder.decode(State.self, from: data)
    }

    private func canCommunicateWithCounterpart(_ session: WatchSessionProtocol) -> Bool {
        #if os(iOS)
        return session.isPaired && session.isWatchAppInstalled
        #else
        return true
        #endif
    }

    private func queueStateRequestTransferIfNeeded(_ payload: [String: Any], over session: WatchSessionProtocol) {
        let alreadyQueued = session.outstandingUserInfoTransfers.contains {
            ($0.userInfo[requestStateKey] as? Bool) == true
        }
        guard !alreadyQueued else {
            GraceWatchLogger.sync("Skipping duplicate state request transferUserInfo")
            return
        }
        _ = session.transferUserInfo(payload)
    }

    private func loadCachedStateIfAvailable() {
        guard let cached = cachedState else { return }
        Task { @MainActor [weak self] in
            guard let self, self.state == nil else { return }
            self.state = cached
        }
    }

    @MainActor
    private func applyLocalState(_ newState: State) {
        if let incomingTimestamped = newState as? WatchTimestampedState,
           let currentTimestamped = self.state as? WatchTimestampedState,
           incomingTimestamped.updatedAt < currentTimestamped.updatedAt {
            GraceWatchLogger.sync("Ignoring stale Watch state (\(incomingTimestamped.updatedAt) < \(currentTimestamped.updatedAt))")
            return
        }

        self.state = newState
        if let defaults = appGroupDefaults, let data = try? encoder.encode(newState) {
            defaults.set(data, forKey: cacheKey)
        }
        if reloadWidgetsOnUpdate {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func sendEncodedState(_ newState: State, over session: WatchSessionProtocol) {
        do {
            let data = try encoder.encode(newState)
            let payload: [String: Any] = [stateKey: data]
            try session.updateApplicationContext(payload)
            lastSentState = newState
            GraceWatchLogger.sync("Pushed applicationContext (\(data.count) bytes)", level: .success)

            if session.isReachable {
                session.sendMessage(payload, replyHandler: nil) { error in
                    GraceWatchLogger.sync("Immediate sendMessage failed (context already updated): \(error.localizedDescription)", level: .warning)
                }
            }
        } catch {
            GraceWatchLogger.sync("Failed to encode/push state: \(error.localizedDescription)", level: .error)
        }
    }

    internal func handleIncomingPayload(
        _ payload: [String: Any],
        replyHandler: (([String: Any]) -> Void)?
    ) {
        if let data = payload[stateKey] as? Data,
           let decoded = try? decoder.decode(State.self, from: data) {
            Task { @MainActor [weak self] in
                self?.applyLocalState(decoded)
            }
            return
        }

        if payload[requestStateKey] as? Bool == true {
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let replyHandler,
                   let current = self.lastSentState ?? self.state,
                   let data = try? self.encoder.encode(current) {
                    replyHandler([self.stateKey: data])
                }
                self.onReceiveAction?(payload, replyHandler)
            }
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            #if os(iOS)
            let isExtension = Bundle.main.bundlePath.hasSuffix(".appex")
            var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
            var sharedApp: UIApplication?
            if !isExtension,
               let appClass = NSClassFromString("UIApplication") as? NSObject.Type,
               let app = appClass.perform(NSSelectorFromString("sharedApplication"))?.takeUnretainedValue() as? UIApplication {
                sharedApp = app
                backgroundTaskID = app.beginBackgroundTask(withName: "GALWatchSync") {}
            }
            defer {
                if let sharedApp, backgroundTaskID != .invalid {
                    sharedApp.endBackgroundTask(backgroundTaskID)
                }
            }
            #endif
            self.onReceiveAction?(payload, replyHandler)
        }
    }

    // MARK: - WCSessionDelegate

    public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            GraceWatchLogger.session("Activation failed: \(error.localizedDescription)", level: .error)
        } else {
            GraceWatchLogger.session("Activation completed: state=\(activationState.rawValue)", level: .info)
        }

        let activated = (activationState == .activated)
        let reachable = session.isReachable
        let receivedContext = session.receivedApplicationContext
        #if os(iOS)
        let watchInstalled = session.isPaired && session.isWatchAppInstalled
        #else
        let watchInstalled = true
        #endif

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isActivated = activated
            self.isReachable = reachable
            self.isWatchAppInstalled = watchInstalled

            guard activated else { return }

            if watchInstalled, let pending = self.pendingState {
                self.pendingState = nil
                self.pushState(pending, force: true)
            }

            if self.pendingStateRequest {
                self.requestStateFromCounterpart()
            } else {
                #if os(watchOS)
                if self.autoRequestStateOnActivate {
                    self.requestStateFromCounterpart()
                }
                #endif
            }

            if !receivedContext.isEmpty {
                self.handleIncomingPayload(receivedContext, replyHandler: nil)
            }

            self.onSessionActivated?()
        }
    }

    public func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor [weak self] in
            self?.isReachable = reachable
        }
    }

    public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handleIncomingPayload(applicationContext, replyHandler: nil)
    }

    public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleIncomingPayload(message, replyHandler: nil)
    }

    public func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        handleIncomingPayload(message, replyHandler: replyHandler)
    }

    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handleIncomingPayload(userInfo, replyHandler: nil)
    }

    #if os(iOS)
    public func sessionWatchStateDidChange(_ session: WCSession) {
        let watchInstalled = session.isPaired && session.isWatchAppInstalled
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isWatchAppInstalled = watchInstalled
            if watchInstalled, let stateToSync = self.pendingState ?? self.state {
                self.pendingState = nil
                self.pushState(stateToSync, force: true)
            }
        }
    }

    public func sessionDidBecomeInactive(_ session: WCSession) {
        GraceWatchLogger.session("Session became inactive", level: .info)
    }

    public func sessionDidDeactivate(_ session: WCSession) {
        GraceWatchLogger.session("Session deactivated; reactivating", level: .info)
        session.activate()
    }
    #endif
}

public extension WatchSyncChannel {
    /// Optimistically mutates the cached `WatchEntitlementEnvelope` payload on the Watch when `isPro == true`.
    @MainActor
    func updateProPayloadIfUnlocked<Payload: Codable & Equatable>(
        at now: Date = Date(),
        _ mutate: (inout Payload) -> Void
    ) where State == WatchEntitlementEnvelope<Payload> {
        guard let envelope = state, envelope.isPro else { return }
        var payload = envelope.payload
        mutate(&payload)
        updateLocalState(WatchEntitlementEnvelope(isPro: true, updatedAt: now, payload: payload))
    }
}
