import XCTest
import WatchConnectivity
@testable import GraceAppsLibraryWatch

private struct SampleWatchPayload: Codable, Equatable {
    let count: Int
    let title: String
}

private final class MockWatchSession: WatchSessionProtocol {
    weak var delegate: WCSessionDelegate?
    var activationState: WCSessionActivationState = .notActivated
    var isReachable: Bool = false
    var receivedApplicationContext: [String: Any] = [:]

    var activateCount = 0
    var updatedContexts: [[String: Any]] = []
    var sentMessages: [[String: Any]] = []
    var transferredUserInfos: [[String: Any]] = []
    var shouldFailSendMessage = false

    func activate() {
        activateCount += 1
        activationState = .activated
    }

    func updateApplicationContext(_ applicationContext: [String: Any]) throws {
        updatedContexts.append(applicationContext)
    }

    func sendMessage(
        _ message: [String: Any],
        replyHandler: (([String: Any]) -> Void)?,
        errorHandler: ((Error) -> Void)?
    ) {
        sentMessages.append(message)
        if shouldFailSendMessage {
            errorHandler?(NSError(domain: "MockWatchSession", code: -1))
        }
    }

    func transferUserInfo(_ userInfo: [String: Any]) -> WCSessionUserInfoTransfer {
        transferredUserInfos.append(userInfo)
        return WCSessionUserInfoTransfer()
    }
}

final class WatchSyncChannelTests: XCTestCase {
    @MainActor
    func testPushStateDeduplicatesAndTransmitsWhenActivated() {
        let mock = MockWatchSession()
        mock.activationState = .activated
        let channel = WatchSyncChannel<WatchEntitlementEnvelope<SampleWatchPayload>>(
            session: mock,
            reloadWidgetsOnUpdate: false
        )

        let envelope = WatchEntitlementEnvelope(
            isPro: true,
            updatedAt: Date(timeIntervalSince1970: 1_000),
            payload: SampleWatchPayload(count: 3, title: "Reading")
        )

        channel.pushState(envelope)
        channel.pushState(envelope)

        XCTAssertEqual(mock.updatedContexts.count, 1)
        XCTAssertEqual(channel.state, envelope)

        channel.pushState(envelope, force: true)
        XCTAssertEqual(mock.updatedContexts.count, 2)
    }

    @MainActor
    func testSendActionUsesSendMessageWhenReachableAndFallsBackToUserInfo() {
        let mock = MockWatchSession()
        mock.activationState = .activated
        mock.isReachable = true
        let channel = WatchSyncChannel<WatchEntitlementEnvelope<SampleWatchPayload>>(
            session: mock,
            reloadWidgetsOnUpdate: false
        )

        channel.sendAction(["action": "start"])
        XCTAssertEqual(mock.sentMessages.count, 1)
        XCTAssertEqual(mock.transferredUserInfos.count, 0)

        mock.shouldFailSendMessage = true
        channel.sendAction(["action": "stop"])
        XCTAssertEqual(mock.sentMessages.count, 2)
        XCTAssertEqual(mock.transferredUserInfos.count, 1)

        mock.isReachable = false
        channel.sendAction(["action": "sync"])
        XCTAssertEqual(mock.sentMessages.count, 2)
        XCTAssertEqual(mock.transferredUserInfos.count, 2)
    }

    @MainActor
    func testIncomingPayloadUpdatesStateAndForwardsActions() async throws {
        let mock = MockWatchSession()
        let channel = WatchSyncChannel<WatchEntitlementEnvelope<SampleWatchPayload>>(
            session: mock,
            reloadWidgetsOnUpdate: false
        )

        let incoming = WatchEntitlementEnvelope(
            isPro: true,
            updatedAt: Date(timeIntervalSince1970: 2_000),
            payload: SampleWatchPayload(count: 10, title: "Session")
        )
        let data = try JSONEncoder().encode(incoming)
        channel.handleIncomingPayload([channel.stateKey: data], replyHandler: nil)

        var receivedAction: [String: Any]?
        let expectation = expectation(description: "action received")
        channel.onReceiveAction = { payload, _ in
            receivedAction = payload
            expectation.fulfill()
        }
        channel.handleIncomingPayload(["start_reading": true], replyHandler: nil)

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(channel.state, incoming)
        XCTAssertEqual(receivedAction?["start_reading"] as? Bool, true)
    }
}
