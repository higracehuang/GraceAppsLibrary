import Combine
import Foundation
import WatchConnectivity
import WidgetKit

/// Generic, testable `WCSession` state & action channel shared between iOS and watchOS targets.
public final class WatchSyncChannel<State: Codable & Equatable>: NSObject, ObservableObject, WCSessionDelegate {
    @MainActor @Published public private(set) var state: State?
    @MainActor @Published public private(set) var isActivated: Bool = false
    @MainActor @Published public private(set) var isReachable: Bool = false

    /// Called on the main actor when an action payload (not a state snapshot) arrives from the counterpart.
    public var onReceiveAction: (@MainActor (_ payload: [String: Any], _ replyHandler: (([String: Any]) -> Void)?) -> Void)?

    /// Called on the main actor once `WCSession` finishes activating.
    public var onSessionActivated: (@MainActor () -> Void)?

    public let stateKey: String
    public let requestStateKey: String
    public let cacheKey: String
    public let reloadWidgetsOnUpdate: Bool

    private let appGroupDefaults: UserDefaults?
    private let session: WatchSessionProtocol?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var lastSentState: State?
    private var pendingState: State?

    public init(
        session: WatchSessionProtocol? = WCSession.isSupported() ? WCSession.default : nil,
        stateKey: String = "gal_watch_state",
        requestStateKey: String = "gal_request_state",
        appGroupSuiteName: String? = nil,
        cacheKey: String = "gal_watch_cached_state",
        reloadWidgetsOnUpdate: Bool = true
    ) {
        self.session = session
        self.stateKey = stateKey
        self.requestStateKey = requestStateKey
        self.appGroupDefaults = appGroupSuiteName.flatMap { UserDefaults(suiteName: $0) }
        self.cacheKey = cacheKey
        self.reloadWidgetsOnUpdate = reloadWidgetsOnUpdate
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
            GraceWatchLogger.sync("Cannot request state: WCSession not activated", level: .warning)
            return
        }

        let payload: [String: Any] = [requestStateKey: true]
        if session.isReachable {
            session.sendMessage(payload, replyHandler: { [weak self] reply in
                self?.handleIncomingPayload(reply, replyHandler: nil)
            }, errorHandler: { [weak self] error in
                GraceWatchLogger.sync("State request failed (\(error.localizedDescription)); falling back to transferUserInfo", level: .warning)
                _ = self?.session?.transferUserInfo(payload)
            })
        } else {
            _ = session.transferUserInfo(payload)
        }
    }

    public func sendAction(_ payload: [String: Any], fallbackToUserInfo: Bool = true) {
        guard let session, session.activationState == .activated else {
            GraceWatchLogger.sync("Cannot send action: WCSession not activated", level: .warning)
            return
        }

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

    private func loadCachedStateIfAvailable() {
        guard let data = appGroupDefaults?.data(forKey: cacheKey),
              let cached = try? decoder.decode(State.self, from: data) else {
            return
        }
        Task { @MainActor [weak self] in
            guard let self, self.state == nil else { return }
            self.state = cached
        }
    }

    @MainActor
    private func applyLocalState(_ newState: State) {
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
            self?.onReceiveAction?(payload, replyHandler)
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

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isActivated = activated
            self.isReachable = reachable

            guard activated else { return }

            if let pending = self.pendingState {
                self.pendingState = nil
                self.pushState(pending, force: true)
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
    public func sessionDidBecomeInactive(_ session: WCSession) {
        GraceWatchLogger.session("Session became inactive", level: .info)
    }

    public func sessionDidDeactivate(_ session: WCSession) {
        GraceWatchLogger.session("Session deactivated; reactivating", level: .info)
        session.activate()
    }
    #endif
}
