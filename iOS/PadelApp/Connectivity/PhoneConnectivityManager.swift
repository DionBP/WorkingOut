import Foundation
import WatchConnectivity
import PadelKit
import WorkingOutKit

@MainActor
final class PhoneConnectivityManager: NSObject, ObservableObject, @preconcurrency WearablePlanTransport {
    static let shared = PhoneConnectivityManager()

    @Published var isWatchReachable: Bool = false
    @Published var isWatchAppInstalled: Bool = false
    @Published var isWatchPaired: Bool = false
    @Published var lastReceivedMatch: MatchState?
    @Published var lastReceivedAmericano: AmericanoSession?

    @Published private(set) var wearableResults: [StrengthSession] = []
    private var wearableContext: Data?
    private var session: WCSession?

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        self.session = session
    }

    func publish(_ feed: WearablePlanFeed) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(feed), data != wearableContext else { return }
        wearableContext = data
        sendWearableContext()
    }

    func acknowledge(_ id: UUID) {
        guard let session, session.activationState == .activated, session.isPaired else { return }
        session.transferUserInfo([WearableMessage.receipt: id.uuidString])
        wearableResults.removeAll { $0.id == id }
    }

    private func sendWearableContext() {
        guard let session, session.activationState == .activated, session.isPaired, let wearableContext else { return }
        try? session.updateApplicationContext([WearableMessage.plans: wearableContext])
    }

    func send(_ payload: SyncPayload) {
        guard let session, session.activationState == .activated else { return }
        let dict: [String: Any] = ["payload": payload.encoded()]
        if session.isReachable {
            session.sendMessage(dict, replyHandler: nil) { [weak self] _ in
                self?.updateContext(dict)
            }
        } else {
            updateContext(dict)
        }
    }

    private func updateContext(_ dict: [String: Any]) {
        guard let session else { return }
        try? session.updateApplicationContext(dict)
    }

    nonisolated private func handleIncoming(_ dict: [String: Any]) {
        guard let data = dict["payload"] as? Data, let payload = SyncPayload.decode(data) else { return }
        Task { @MainActor in
            switch payload {
            case .match(let state), .matchFinished(let state):
                self.lastReceivedMatch = state
            case .americano(let session), .americanoFinished(let session):
                self.lastReceivedAmericano = session
            case .requestLatest, .clearActiveSession, .playerRoster, .workoutAutoEnd:
                break
            }
        }
    }
}

extension PhoneConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        Task { @MainActor in
            self.sendWearableContext()
            self.isWatchPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isWatchReachable = session.isReachable
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isWatchReachable = session.isReachable
        }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.sendWearableContext()
            self.isWatchPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handleIncoming(applicationContext)
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleIncoming(message)
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        if let bytes = userInfo[WearableMessage.result] as? Data,
           let workout = try? JSONDecoder().decode(StrengthSession.self, from: bytes) {
            Task { @MainActor in
                guard !self.wearableResults.contains(where: { $0.id == workout.id }) else { return }
                self.wearableResults.append(workout)
            }
        } else {
            handleIncoming(userInfo)
        }
    }
}
