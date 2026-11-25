import Foundation

public struct WearableExercise: Codable, Identifiable, Sendable {
    public var id: UUID { exercise.id }
    public var exercise: StrengthExercise
    public let previous: [StrengthSet]
    public let recommendation: ProgressionRecommendation?
    public let restSeconds: Int

    public init(exercise: StrengthExercise, previous: [StrengthSet], recommendation: ProgressionRecommendation?, restSeconds: Int) {
        self.exercise = exercise
        self.previous = previous
        self.recommendation = recommendation
        self.restSeconds = min(600, max(15, restSeconds))
    }
}

public struct WearablePlan: Codable, Identifiable, Sendable {
    public let id: String
    public let programID: UUID
    public let title: String
    public let scheduledFor: Date?
    public let exercises: [WearableExercise]

    public init(id: String, programID: UUID, title: String, scheduledFor: Date?, exercises: [WearableExercise]) {
        self.id = id
        self.programID = programID
        self.title = title
        self.scheduledFor = scheduledFor
        self.exercises = exercises
    }
}

public struct WearablePlanFeed: Codable, Sendable {
    public let schema: Int
    public let plans: [WearablePlan]
    public let replacements: [WearableExercise]
    public let language: String
    public let weight: WeightUnit
    public let distance: DistanceUnit

    public init(plans: [WearablePlan] = [], replacements: [WearableExercise] = [], language: String = "",
                weight: WeightUnit = .kg, distance: DistanceUnit = .km) {
        schema = 1
        self.plans = plans
        self.replacements = replacements
        self.language = language
        self.weight = weight
        self.distance = distance
    }
}

public protocol WearablePlanTransport {
    /// Publish a complete replacement snapshot so devices can recover after missed updates.
    func publish(_ feed: WearablePlanFeed)
}

public struct WearableWorkout: Codable, Identifiable, Sendable {
    public let id: UUID
    public let programID: UUID
    public let title: String
    public let occurrenceID: String?
    public let started: Date
    private let originalExerciseIDs: [UUID]
    public var exercises: [WearableExercise]
    public private(set) var skipped: Set<UUID> = []
    public private(set) var paused: Date?
    public private(set) var pausedSeconds: TimeInterval = 0
    public private(set) var restUntil: Date?
    public private(set) var finished: Date?

    public init(plan: WearablePlan, now: Date) {
        id = UUID()
        programID = plan.programID
        title = plan.title
        occurrenceID = plan.scheduledFor == nil ? nil : plan.id
        started = now
        exercises = plan.exercises
        originalExerciseIDs = plan.exercises.map(\.id)
    }

    public var exerciseIndex: Int? {
        exercises.firstIndex { !skipped.contains($0.id) && $0.exercise.sets.contains { !$0.done } }
    }

    public var setIndex: Int? {
        exerciseIndex.flatMap { exercises[$0].exercise.sets.firstIndex { !$0.done } }
    }

    public var upcoming: WearableExercise? {
        guard let index = exerciseIndex else { return nil }
        return exercises.dropFirst(index + 1).first { !skipped.contains($0.id) }
    }

    public var elapsed: TimeInterval {
        duration(at: .now)
    }

    public func duration(at date: Date) -> TimeInterval {
        max(0, (finished ?? paused ?? date).timeIntervalSince(started) - pausedSeconds)
    }

    public mutating func adjustCurrent(kg: Double? = nil, reps: Int? = nil) {
        guard finished == nil, let index = exerciseIndex, let set = setIndex else { return }
        if let kg, kg.isFinite, kg >= 0 { exercises[index].exercise.sets[set].kg = kg }
        if let reps, reps > 0 { exercises[index].exercise.sets[set].reps = reps }
    }

    public mutating func completeSet(at date: Date) {
        guard finished == nil, paused == nil, (restUntil ?? .distantPast) <= date,
              let index = exerciseIndex, let set = setIndex else { return }
        let current = exercises[index].exercise.sets[set]
        guard current.kg >= 0, current.kg.isFinite, current.reps > 0 else { return }
        exercises[index].exercise.sets[set].done = true
        restUntil = exerciseIndex == nil ? nil : date.addingTimeInterval(Double(exercises[index].restSeconds))
    }

    public mutating func skipRest() { restUntil = nil }

    public mutating func skipExercise() {
        guard finished == nil, let index = exerciseIndex else { return }
        skipped.insert(exercises[index].id)
        skipRest()
    }

    public mutating func replaceExercise(with replacement: WearableExercise) {
        guard finished == nil, let index = exerciseIndex else { return }
        // Preserve any completed sets at the original position for the final log.
        var item = replacement
        item.exercise.id = UUID()
        item.exercise.sets = item.exercise.sets.map { StrengthSet(kg: $0.kg, reps: $0.reps, warmup: $0.warmup) }
        if exercises[index].exercise.sets.contains(where: \.done) {
            skipExercise()
            exercises.insert(item, at: index + 1)
        } else {
            exercises[index] = item
            skipRest()
        }
    }

    public mutating func togglePause(at date: Date) {
        guard finished == nil else { return }
        if let paused {
            pausedSeconds += max(0, date.timeIntervalSince(paused))
            self.paused = nil
        } else {
            paused = date
        }
    }

    public mutating func finish(at date: Date) -> StrengthSession? {
        guard finished == nil else { return nil }
        let completePlan = originalExerciseIDs.allSatisfy { id in
            exercises.first(where: { $0.id == id })?.exercise.finishedPlannedWorkingSets == true
        }
        var completed = exercises.map(\.exercise)
        for index in completed.indices {
            completed[index].fromCompletePlan = completePlan
            completed[index].sets.removeAll { !$0.metric.isValid }
        }
        completed.removeAll { $0.sets.isEmpty }
        guard !completed.isEmpty else { return nil }
        let duration = duration(at: date)
        finished = date
        var item = StrengthSession(date: started, exercises: completed, duration: duration)
        item.id = id
        item.endDate = date
        item.occurrenceID = occurrenceID
        return item
    }
}

public enum WearableMessage {
    public static let plans = "workingout.plans.v1"
    public static let result = "workingout.result.v1"
    public static let receipt = "workingout.receipt.v1"
    public static let healthSyncPrefix = "workingout-watch:"
}

public extension StrengthLog {
    @discardableResult
    mutating func receiveWearableSession(_ workout: StrengthSession) -> Bool {
        guard !(receivedWearableIDs ?? []).contains(workout.id),
              !history.contains(where: { $0.id == workout.id || $0.healthID != nil && $0.healthID == workout.healthID }),
              !(hiddenSyncIDs ?? []).contains(workout.id),
              !workout.exercises.isEmpty,
              workout.exercises.allSatisfy({ !$0.sets.isEmpty && $0.sets.allSatisfy(\.metric.isValid) }) else { return false }
        history.append(workout)
        receivedWearableIDs = (receivedWearableIDs ?? []) + [workout.id]
        return true
    }
}
