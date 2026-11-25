import XCTest
import WatchConnectivity
@testable import GraceAppsLibraryWatch

private struct SampleWatchPayload: Codable, Equatable {
    let count: Int
    let title: String
}

private final class MockUserInfoTransfer: WCSessionUserInfoTransfer {
    private let mockUserInfo: [String: Any]

    init(userInfo: [String: Any]) {
        self.mockUserInfo = userInfo
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var userInfo: [String: Any] {
        mockUserInfo
    }
}

private final class MockWatchSession: WatchSessionProtocol {
    weak var delegate: WCSessionDelegate?
    var activationState: WCSessionActivationState = .notActivated
    var isReachable: Bool = false
    var receivedApplicationContext: [String: Any] = [:]
    var outstandingUserInfoTransfers: [WCSessionUserInfoTransfer] = []
    #if os(iOS)
    var isPaired: Bool = true
    var isWatchAppInstalled: Bool = true
    #endif

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
        let transfer = MockUserInfoTransfer(userInfo: userInfo)
        outstandingUserInfoTransfers.append(transfer)
        return transfer
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

    #if os(iOS)
    @MainActor
    func testPushStateSkipsTransmissionWhenWatchNotInstalled() {
        let mock = MockWatchSession()
        mock.activationState = .activated
        mock.isPaired = true
        mock.isWatchAppInstalled = false

        let channel = WatchSyncChannel<WatchEntitlementEnvelope<SampleWatchPayload>>(
            session: mock,
            reloadWidgetsOnUpdate: false
        )

        let envelope = WatchEntitlementEnvelope(
            isPro: true,
            updatedAt: Date(timeIntervalSince1970: 1_000),
            payload: SampleWatchPayload(count: 5, title: "Queued")
        )

        channel.pushState(envelope)
        XCTAssertEqual(mock.updatedContexts.count, 0)
        XCTAssertEqual(channel.state, envelope)
    }
    #endif

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
    func testRequestStateDeduplicatesOutstandingOfflineTransfers() {
        let mock = MockWatchSession()
        mock.activationState = .activated
        mock.isReachable = false
        let channel = WatchSyncChannel<WatchEntitlementEnvelope<SampleWatchPayload>>(
            session: mock,
            reloadWidgetsOnUpdate: false
        )

        channel.requestStateFromCounterpart()
        channel.requestStateFromCounterpart()

        XCTAssertEqual(mock.transferredUserInfos.count, 1)
    }

    @MainActor
    func testIncomingPayloadIgnoresStaleTimestampedState() async throws {
        let mock = MockWatchSession()
        mock.activationState = .activated
        let channel = WatchSyncChannel<WatchEntitlementEnvelope<SampleWatchPayload>>(
            session: mock,
            reloadWidgetsOnUpdate: false
        )

        let newer = WatchEntitlementEnvelope(
            isPro: true,
            updatedAt: Date(timeIntervalSince1970: 2_000),
            payload: SampleWatchPayload(count: 10, title: "Newer")
        )
        let older = WatchEntitlementEnvelope(
            isPro: false,
            updatedAt: Date(timeIntervalSince1970: 1_000),
            payload: SampleWatchPayload(count: 1, title: "Older")
        )

        channel.handleIncomingPayload([channel.stateKey: try JSONEncoder().encode(newer)], replyHandler: nil)
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(channel.state, newer)

        channel.handleIncomingPayload([channel.stateKey: try JSONEncoder().encode(older)], replyHandler: nil)
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(channel.state, newer)
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

    @MainActor
    func testUpdateProPayloadIfUnlockedMutatesOnlyWhenPro() {
        let mock = MockWatchSession()
        mock.activationState = .activated
        let channel = WatchSyncChannel<WatchEntitlementEnvelope<SampleWatchPayload>>(
            session: mock,
            reloadWidgetsOnUpdate: false
        )

        let free = WatchEntitlementEnvelope(
            isPro: false,
            updatedAt: Date(timeIntervalSince1970: 1_000),
            payload: SampleWatchPayload(count: 1, title: "Free")
        )
        channel.updateLocalState(free)
        channel.updateProPayloadIfUnlocked { $0 = SampleWatchPayload(count: 99, title: "Changed") }
        XCTAssertEqual(channel.state?.payload.count, 1)

        let pro = WatchEntitlementEnvelope(
            isPro: true,
            updatedAt: Date(timeIntervalSince1970: 2_000),
            payload: SampleWatchPayload(count: 1, title: "Pro")
        )
        channel.updateLocalState(pro)
        channel.updateProPayloadIfUnlocked(at: Date(timeIntervalSince1970: 3_000)) {
            $0 = SampleWatchPayload(count: 2, title: "ProUpdated")
        }
        XCTAssertEqual(channel.state?.payload.count, 2)
        XCTAssertEqual(channel.state?.payload.title, "ProUpdated")
    }

    @MainActor
    func testSendTimestampedActionPacksAndExtractsTimestamp() {
        let mock = MockWatchSession()
        mock.activationState = .activated
        mock.isReachable = true
        let channel = WatchSyncChannel<WatchEntitlementEnvelope<SampleWatchPayload>>(
            session: mock,
            reloadWidgetsOnUpdate: false
        )

        let timestamp = Date(timeIntervalSince1970: 12_345)
        channel.sendTimestampedAction("start_reading", at: timestamp)

        XCTAssertEqual(mock.sentMessages.count, 1)
        let sent = mock.sentMessages[0]
        XCTAssertEqual(sent["start_reading"] as? Bool, true)
        let extracted = WatchSyncChannel<WatchEntitlementEnvelope<SampleWatchPayload>>.actionTimestamp(from: sent)
        XCTAssertEqual(extracted.timeIntervalSince1970, timestamp.timeIntervalSince1970, accuracy: 0.001)
    }
}
