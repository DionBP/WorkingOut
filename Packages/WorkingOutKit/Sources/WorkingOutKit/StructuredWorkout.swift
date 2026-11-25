import Foundation

/// An internal draft for a supported wearable provider. Providers must translate
/// these fields into their approved API schema and validate their device limits.
public struct StructuredWorkoutDraft: Equatable, Sendable {
    public struct Step: Equatable, Sendable {
        public let exerciseID: String
        public let providerExerciseCode: String?
        public let warmup: Bool
        public let kilograms: Double
        public let minimumReps: Int
        public let maximumReps: Int
        public let restSeconds: Int
        public let loadKind: LoadKind
    }

    public let planID: String
    public let programID: UUID
    public let scheduledFor: Date?
    public let title: String
    public let steps: [Step]

    public var unresolvedExercises: Set<String> {
        Set(steps.filter { $0.providerExerciseCode == nil }.map(\.exerciseID))
    }

    public init(plan: WearablePlan, exerciseCodes: [String: String]) {
        planID = plan.id
        programID = plan.programID
        scheduledFor = plan.scheduledFor
        title = plan.title
        steps = plan.exercises.flatMap { item in
            item.exercise.sets.map { set in
                let range = set.warmup == true || item.exercise.progression?.strategy != .doubleProgression
                    ? nil : item.exercise.progression
                let id = item.exercise.identity
                return Step(exerciseID: id, providerExerciseCode: exerciseCodes[id],
                            warmup: set.warmup == true, kilograms: set.kg, minimumReps: range?.minimum ?? set.reps,
                            maximumReps: range?.maximum ?? set.reps, restSeconds: item.restSeconds,
                            loadKind: item.exercise.progression?.loadKind ?? .external)
            }
        }
    }
}

public protocol StructuredWorkoutProvider {
    /// Implementations must verify authorization and capability before sending data.
    func schedule(_ workout: StructuredWorkoutDraft) async throws -> String
}
