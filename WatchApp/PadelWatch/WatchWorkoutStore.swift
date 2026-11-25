import Foundation
import Combine
import WatchConnectivity
import WatchKit
import WorkingOutKit

@MainActor
final class WatchWorkoutStore: NSObject, ObservableObject {
    private struct Snapshot: Codable {
        var feed = WearablePlanFeed()
        var active: WearableWorkout?
        var pending: [StrengthSession] = []
        var completedOccurrences: Set<String> = []
    }

    @Published private var snapshot = Snapshot()
    @Published var error = false
    @Published private(set) var savingHealth = false
    private var inaccessible = false
    private let url = URL.documentsDirectory.appendingPathComponent("workingout-watch-v1.json")
    private let health: WatchWorkoutHealth
    private let connectivity: WCSession?

    var feed: WearablePlanFeed { snapshot.feed }
    var active: WearableWorkout? { snapshot.active }

    init(health: WatchWorkoutHealth) {
        self.health = health
        connectivity = WCSession.isSupported() ? WCSession.default : nil
        super.init()
        do {
            snapshot = try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: url))
        } catch let issue as CocoaError where issue.code == .fileReadNoSuchFile {
            // First launch.
        } catch {
            inaccessible = true
            self.error = true
        }
        connectivity?.delegate = self
        connectivity?.activate()
        if let active { health.recover(id: active.id) }
    }

    func start(_ plan: WearablePlan) {
        guard active == nil, !savingHealth, !plan.exercises.isEmpty, !snapshot.completedOccurrences.contains(plan.id) else { return }
        let workout = WearableWorkout(plan: plan, now: .now)
        if update({ $0.active = workout }) { health.start(id: workout.id, at: workout.started) }
    }

    func canOffer(_ plan: WearablePlan) -> Bool {
        guard !snapshot.completedOccurrences.contains(plan.id) else { return false }
        return plan.scheduledFor.map { Calendar.current.isDateInToday($0) } ?? true
    }

    func change(_ apply: (inout WearableWorkout) -> Void) {
        guard var workout = active else { return }
        apply(&workout)
        update { $0.active = workout }
    }

    func completeSet() {
        guard let workout = active else { return }
        change { $0.completeSet(at: .now) }
        if active?.exerciseIndex != workout.exerciseIndex || active?.setIndex != workout.setIndex {
            WKInterfaceDevice.current().play(.click)
        }
    }

    func togglePause() {
        let wasPaused = active?.paused != nil
        change { $0.togglePause(at: .now) }
        if wasPaused && active?.paused == nil { health.resume() }
        if !wasPaused && active?.paused != nil { health.pause() }
    }

    func discard() {
        guard active != nil, update({ $0.active = nil }) else { return }
        health.discard()
    }

    func finish() {
        guard var workout = active, !savingHealth, let completed = workout.finish(at: .now) else { return }
        guard update({ state in
            state.active = nil
            state.pending.append(completed)
            if let occurrence = completed.occurrenceID { state.completedOccurrences.insert(occurrence) }
        }) else { return }
        savingHealth = true
        Task {
            if let linked = await health.finish(id: completed.id, at: completed.endDate ?? .now) {
                update { state in
                    if let index = state.pending.firstIndex(where: { $0.id == completed.id }) {
                        state.pending[index].healthID = linked
                    }
                }
            }
            savingHealth = false
            flush()
        }
    }

    @discardableResult
    private func update(_ apply: (inout Snapshot) -> Void) -> Bool {
        guard !inaccessible else { error = true; return false }
        var next = snapshot
        apply(&next)
        do {
            try JSONEncoder().encode(next).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            snapshot = next
            return true
        } catch {
            self.error = true
            return false
        }
    }

    private func flush() {
        guard let connectivity, connectivity.activationState == .activated, !savingHealth else { return }
        let inflight = Set(connectivity.outstandingUserInfoTransfers.compactMap { transfer -> UUID? in
            guard let data = transfer.userInfo[WearableMessage.result] as? Data else { return nil }
            return (try? JSONDecoder().decode(StrengthSession.self, from: data))?.id
        })
        for pending in snapshot.pending where !inflight.contains(pending.id) {
            if let data = try? JSONEncoder().encode(pending) {
                connectivity.transferUserInfo([WearableMessage.result: data])
            }
        }
    }

    func becameActive() { flush() }

    private func receiveFeed(_ data: Data) {
        guard let feed = try? JSONDecoder().decode(WearablePlanFeed.self, from: data), feed.schema == 1 else { return }
        update { $0.feed = feed }
    }
}

extension WatchWorkoutStore: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let data = session.receivedApplicationContext[WearableMessage.plans] as? Data
        Task { @MainActor in
            if let data { self.receiveFeed(data) }
            self.flush()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext[WearableMessage.plans] as? Data else { return }
        Task { @MainActor in self.receiveFeed(data) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let value = userInfo[WearableMessage.receipt] as? String, let id = UUID(uuidString: value) else { return }
        Task { @MainActor in self.update { $0.pending.removeAll { $0.id == id } } }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.flush() }
    }
}
