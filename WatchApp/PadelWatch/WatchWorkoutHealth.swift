import Foundation
import Combine
import HealthKit
import WorkingOutKit

@MainActor
final class WatchWorkoutHealth: NSObject, ObservableObject {
    @Published private(set) var heartRate: Double?
    @Published private(set) var energy: Double?
    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var workoutID: UUID?
    private var collecting = false

    func start(id: UUID, at date: Date) {
        guard HKHealthStore.isHealthDataAvailable(), workoutID == nil else { return }
        workoutID = id
        Task {
            do {
                let heart = HKQuantityType(.heartRate)
                let calories = HKQuantityType(.activeEnergyBurned)
                if store.authorizationStatus(for: .workoutType()) == .notDetermined {
                    try await store.requestAuthorization(toShare: [.workoutType()], read: [heart, calories])
                }
                guard workoutID == id else { return }
                guard store.authorizationStatus(for: .workoutType()) == .sharingAuthorized else { reset(); return }
                let configuration = HKWorkoutConfiguration()
                configuration.activityType = .traditionalStrengthTraining
                configuration.locationType = .indoor
                let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
                let builder = session.associatedWorkoutBuilder()
                builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: configuration)
                install(session, builder: builder)
                session.startActivity(with: date)
                try await builder.beginCollection(at: date)
                guard workoutID == id else { return }
                collecting = true
            } catch {
                if workoutID == id { discard() }
            }
        }
    }

    func recover(id: UUID) {
        guard HKHealthStore.isHealthDataAvailable(), workoutID == nil else { return }
        workoutID = id
        store.recoverActiveWorkoutSession { recovered, _ in
            Task { @MainActor in
                guard self.workoutID == id else { return }
                guard let recovered, recovered.workoutConfiguration.activityType == .traditionalStrengthTraining else {
                    self.reset()
                    return
                }
                self.install(recovered, builder: recovered.associatedWorkoutBuilder())
                self.collecting = true
            }
        }
    }

    func pause() { session?.pause() }
    func resume() { session?.resume() }

    func finish(id: UUID, at date: Date) async -> UUID? {
        guard workoutID == id, collecting, let session, let builder else {
            discard()
            return nil
        }
        defer { reset() }
        session.end()
        do {
            try await builder.addMetadata([
                HKMetadataKeySyncIdentifier: WearableMessage.healthSyncPrefix + id.uuidString,
                HKMetadataKeySyncVersion: 1
            ])
            try await builder.endCollection(at: date)
            return try await builder.finishWorkout()?.uuid
        } catch {
            builder.discardWorkout()
            return nil
        }
    }

    func discard() {
        session?.end()
        builder?.discardWorkout()
        reset()
    }

    private func install(_ session: HKWorkoutSession, builder: HKLiveWorkoutBuilder) {
        self.session = session
        self.builder = builder
        session.delegate = self
        builder.delegate = self
    }

    private func reset() {
        session = nil
        builder = nil
        workoutID = nil
        collecting = false
        heartRate = nil
        energy = nil
    }
}

extension WatchWorkoutHealth: HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
                                    from fromState: HKWorkoutSessionState, date: Date) {}

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            if self.session === workoutSession { self.discard() }
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        Task { @MainActor in
            guard self.builder === workoutBuilder else { return }
            let pulse = HKQuantityType(.heartRate)
            let calories = HKQuantityType(.activeEnergyBurned)
            self.heartRate = workoutBuilder.statistics(for: pulse)?.mostRecentQuantity()?
                .doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            self.energy = workoutBuilder.statistics(for: calories)?.sumQuantity()?.doubleValue(for: .kilocalorie())
        }
    }
}
