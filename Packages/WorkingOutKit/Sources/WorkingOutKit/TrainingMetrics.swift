import Foundation

public struct TrainingSet: Equatable, Sendable {
    public let kilograms: Double
    public let repetitions: Int
    public let completed: Bool
    public init(kilograms: Double, repetitions: Int, completed: Bool) {
        self.kilograms = kilograms
        self.repetitions = repetitions
        self.completed = completed
    }
    public var isValid: Bool { completed && kilograms.isFinite && kilograms >= 0 && repetitions > 0 }
}

public enum TrainingMetrics {
    public static func volume(_ sets: [TrainingSet]) -> Double {
        sets.filter(\.isValid).reduce(0) { $0 + $1.kilograms * Double($1.repetitions) }
    }

    public static func heaviestWeight(_ sets: [TrainingSet]) -> Double? {
        sets.filter(\.isValid).map(\.kilograms).max()
    }

    /// Epley estimate; a single repetition is the recorded weight.
    /// Limit estimates to 10 reps, where the approximation is more useful.
    public static func estimatedOneRepMax(_ set: TrainingSet) -> Double? {
        guard set.isValid, set.kilograms > 0, set.repetitions <= 10 else { return nil }
        return set.repetitions == 1 ? set.kilograms : set.kilograms * (1 + Double(set.repetitions) / 30)
    }

    public static func runningPaceSeconds(duration: TimeInterval, kilometers: Double) -> Int? {
        guard duration.isFinite, duration > 0, kilometers.isFinite, kilometers > 0 else { return nil }
        let pace = (duration / kilometers).rounded()
        guard pace.isFinite, pace >= 1, pace < Double(Int.max) else { return nil }
        return Int(pace)
    }

    public static func weeklyProgress(completed: Int, goal: Int) -> Double {
        guard goal > 0 else { return 0 }
        return Double(min(max(completed, 0), goal)) / Double(goal)
    }
}
