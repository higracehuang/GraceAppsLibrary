import Foundation
import WatchConnectivity

/// Abstraction over `WCSession` enabling deterministic unit testing of Watch sync logic.
public protocol WatchSessionProtocol: AnyObject {
    var delegate: WCSessionDelegate? { get set }
    var activationState: WCSessionActivationState { get }
    var isReachable: Bool { get }
    var receivedApplicationContext: [String: Any] { get }
    var outstandingUserInfoTransfers: [WCSessionUserInfoTransfer] { get }
    #if os(iOS)
    var isPaired: Bool { get }
    var isWatchAppInstalled: Bool { get }
    #endif

    func activate()
    func updateApplicationContext(_ applicationContext: [String: Any]) throws
    func sendMessage(
        _ message: [String: Any],
        replyHandler: (([String: Any]) -> Void)?,
        errorHandler: ((Error) -> Void)?
    )
    func transferUserInfo(_ userInfo: [String: Any]) -> WCSessionUserInfoTransfer
}

extension WCSession: WatchSessionProtocol {}
