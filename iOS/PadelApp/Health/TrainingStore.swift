import Foundation
import Combine
import HealthKit
import CoreLocation
import WorkingOutKit

@MainActor
final class TrainingStore: ObservableObject {
    @Published private(set) var workouts: [HKWorkout] = []
    @Published private(set) var canWrite = false
    @Published var issue: String?
    private let health = HKHealthStore()
    private var refreshing = false
    private var refreshPending = false

    var available: Bool { HKHealthStore.isHealthDataAvailable() }

    func connect() async {
        guard available else { issue = "healthUnavailable"; return }
        do {
            let read: Set<HKObjectType> = [
                HKObjectType.workoutType(), HKSeriesType.workoutRoute(),
                HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned), HKQuantityType(.distanceWalkingRunning)
            ]
            try await health.requestAuthorization(toShare: [.workoutType()], read: read)
            await refresh()
        } catch { issue = "healthAuthorizationError" }
    }

    func refresh(reportErrors: Bool = false) async {
        guard available else { return }
        canWrite = health.authorizationStatus(for: .workoutType()) == .sharingAuthorized
        guard !refreshing else { refreshPending = true; return }
        refreshing = true
        defer { refreshing = false }
        let predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            HKQuery.predicateForWorkouts(with: .running),
            HKQuery.predicateForWorkouts(with: .traditionalStrengthTraining),
            HKQuery.predicateForWorkouts(with: .functionalStrengthTraining)
        ])
        repeat {
            refreshPending = false
            do {
                workouts = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKWorkout], Error>) in
                    let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate,
                        limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, samples, error in
                        if let error { continuation.resume(throwing: error) }
                        else { continuation.resume(returning: samples as? [HKWorkout] ?? []) }
                    }
                    health.execute(query)
                }
            } catch {
                if reportErrors { issue = "healthReadError" }
            }
        } while refreshPending
    }

    func unlinkedWorkouts(_ log: StrengthLog) -> [HKWorkout] {
        let hiddenIDs = Set(log.hiddenHealthIDs ?? [])
        let hiddenSyncIDs = Set(log.hiddenSyncIDs ?? [])
        let runs = log.runs ?? []
        return workouts.filter { workout in
            if hiddenIDs.contains(workout.uuid) { return false }
            if hiddenSyncIDs.contains(where: { owns(workout, id: $0) }) {
                return false
            }
            if workout.workoutActivityType == .running {
                return !runs.contains { $0.healthID == workout.uuid || owns(workout, id: $0.id) }
            }
            guard workout.workoutActivityType == .traditionalStrengthTraining else { return true }
            return !log.history.contains { session in
                if owns(workout, id: session.id) { return true }
                return ActivityReconciliation.matches(
                    localID: session.healthID, localStart: session.date, localDuration: session.duration,
                    externalID: workout.uuid, externalStart: workout.startDate, externalDuration: workout.duration,
                    isOwnSource: workout.sourceRevision.source.bundleIdentifier == Bundle.main.bundleIdentifier
                )
            }
        }
    }

    func mirror(_ session: StrengthSession) async -> UUID? {
        guard available, health.authorizationStatus(for: .workoutType()) == .sharingAuthorized,
              let duration = session.duration, duration > 0 else { return nil }
        let workout = HKWorkout(
            activityType: .traditionalStrengthTraining, start: session.date, end: session.endDate ?? session.date.addingTimeInterval(duration),
            duration: duration, totalEnergyBurned: nil, totalDistance: nil,
            metadata: [HKMetadataKeySyncIdentifier: session.id.uuidString, HKMetadataKeySyncVersion: 1]
        )
        do {
            try await health.save(workout)
            await refresh()
            return workout.uuid
        } catch {
            issue = "healthWriteError"
            return nil
        }
    }

    func mirror(_ run: RunRecord) async -> UUID? {
        guard available, health.authorizationStatus(for: .workoutType()) == .sharingAuthorized,
              let finish = run.finishDate, run.elapsed(at: finish) > 0 else { return nil }
        let workout = HKWorkout(
            activityType: .running, start: run.date, end: finish, duration: run.elapsed(at: finish),
            totalEnergyBurned: nil, totalDistance: run.meters.map { HKQuantity(unit: .meter(), doubleValue: $0) },
            metadata: [HKMetadataKeySyncIdentifier: run.id.uuidString, HKMetadataKeySyncVersion: 1]
        )
        do {
            try await health.save(workout)
            await refresh()
            return workout.uuid
        } catch {
            issue = "healthWriteError"
            return nil
        }
    }

    func route(for id: UUID) async throws -> [[CLLocation]] {
        guard let workout = workouts.first(where: { $0.uuid == id }) else { return [] }
        let routes: [HKWorkoutRoute] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: HKSeriesType.workoutRoute(), predicate: HKQuery.predicateForObjects(from: workout),
                                      limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: samples as? [HKWorkoutRoute] ?? []) }
            }
            health.execute(query)
        }
        var result: [[CLLocation]] = []
        for route in routes {
            let stream = AsyncThrowingStream<[CLLocation], Error> { continuation in
                let query = HKWorkoutRouteQuery(route: route) { _, points, done, error in
                    if let error { continuation.finish(throwing: error); return }
                    if let points { continuation.yield(points) }
                    if done { continuation.finish() }
                }
                health.execute(query)
            }
            var segment: [CLLocation] = []
            for try await points in stream { segment.append(contentsOf: points) }
            if segment.count > 1 { result.append(segment) }
        }
        return result
    }

    private func owns(_ workout: HKWorkout, id: UUID) -> Bool {
        let source = workout.sourceRevision.source.bundleIdentifier
        let syncID = workout.metadata?[HKMetadataKeySyncIdentifier] as? String
        let phone = Bundle.main.bundleIdentifier ?? ""
        return (source == phone && syncID == id.uuidString) ||
            (source == Bundle.main.object(forInfoDictionaryKey: "WorkingOutWatchBundleIdentifier") as? String &&
             syncID == WearableMessage.healthSyncPrefix + id.uuidString)
    }
}
