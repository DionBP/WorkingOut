import Foundation
import Combine
import HealthKit

@MainActor
final class TrainingStore: ObservableObject {
    @Published var kind: HKWorkoutActivityType = .traditionalStrengthTraining
    @Published var started: Date?
    @Published var error: String?
    @Published private(set) var workouts: [HKWorkout] = []
    @Published private(set) var connected = false
    @Published private(set) var saving = false
    private let health = HKHealthStore()
    private var refreshing = false

    var recent: [HKWorkout] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return workouts.filter { $0.startDate >= cutoff }
    }

    func connect() async {
        guard HKHealthStore.isHealthDataAvailable() else { error = "Apple Health is unavailable."; return }
        do {
            var read: Set<HKObjectType> = [HKObjectType.workoutType()]
            for identifier: HKQuantityTypeIdentifier in [.heartRate, .activeEnergyBurned, .distanceWalkingRunning] {
                if let type = HKObjectType.quantityType(forIdentifier: identifier) { read.insert(type) }
            }
            try await health.requestAuthorization(toShare: [HKObjectType.workoutType()], read: read)
            connected = true
            await refresh()
        } catch { self.error = error.localizedDescription }
    }

    func refresh() async {
        guard HKHealthStore.isHealthDataAvailable(), !refreshing else { return }
        refreshing = true
        defer { refreshing = false }
        let predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            HKQuery.predicateForWorkouts(with: .running),
            HKQuery.predicateForWorkouts(with: .traditionalStrengthTraining),
            HKQuery.predicateForWorkouts(with: .functionalStrengthTraining)
        ])
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
            if connected { self.error = error.localizedDescription }
        }
    }

    func finish() async {
        guard let start = started, !saving else { return }
        saving = true
        defer { saving = false }
        if health.authorizationStatus(for: .workoutType()) != .sharingAuthorized { await connect() }
        guard health.authorizationStatus(for: .workoutType()) == .sharingAuthorized else {
            error = "Allow WorkingOut to save workouts in Apple Health."; return
        }
        let workout = HKWorkout(activityType: kind, start: start, end: Date())
        do {
            try await health.save(workout)
            started = nil
            await refresh()
        } catch { self.error = error.localizedDescription }
    }
}
