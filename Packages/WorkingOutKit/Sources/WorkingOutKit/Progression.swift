import Foundation

public enum ProgressionStrategy: String, Codable, CaseIterable, Identifiable, Sendable {
    case doubleProgression, manual
    public var id: Self { self }
}

public enum LoadKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case external, bodyweight, assisted
    public var id: Self { self }
}

public struct ProgressionTarget: Codable, Sendable {
    public var minimum = 8
    public var maximum = 12
    public var incrementKg: Double?
    public var useLastLoad: Bool?
    public var strategy = ProgressionStrategy.doubleProgression
    public var loadKind = LoadKind.external

    public init() {}

    public var isValid: Bool {
        (1...100).contains(minimum) && (minimum...100).contains(maximum) &&
            (incrementKg.map { $0.isFinite && $0 > 0 } ?? true)
    }

    public static func defaultIncrement(equipment: String?) -> Double {
        switch equipment {
        case "dumbbells": 1
        case "machine", "cable": 5
        default: 2.5
        }
    }
}

public struct ProgressionRecommendation: Codable, Sendable {
    public enum Reason: String, Codable, Sendable {
        case increase, reduce, maintain, bodyweight, insufficient, manual, highEffort
    }
    public let kg: Double
    public let reps: Int
    public let reason: Reason
    public let estimatedMaxKg: Double?
}

public enum DoubleProgression {
    /// History is newest first. Only comparable, completed working sets count.
    public static func recommend(target: ProgressionTarget, workingSets: Int, kg: Double,
                                 equipment: String?, history: [StrengthExercise]) -> ProgressionRecommendation? {
        guard target.isValid, workingSets > 0, kg.isFinite, kg >= 0 else { return nil }
        let increment = target.incrementKg ?? ProgressionTarget.defaultIncrement(equipment: equipment)
        let comparable = Array(history.prefix(2)).map { exercise in
            exercise.sets.filter { $0.warmup != true }
        }
        func result(_ reason: ProgressionRecommendation.Reason, kg load: Double, reps: Int) -> ProgressionRecommendation? {
            guard load.isFinite else { return nil }
            let estimate = target.loadKind == .external
                ? comparable.first?.compactMap { TrainingMetrics.estimatedOneRepMax($0.metric) }.max() : nil
            return ProgressionRecommendation(kg: load, reps: reps, reason: reason, estimatedMaxKg: estimate)
        }
        if target.strategy == .manual { return result(.manual, kg: kg, reps: target.minimum) }
        guard comparable.count == 2,
              comparable.allSatisfy({ sets in
                  sets.count == workingSets && sets.allSatisfy { $0.metric.isValid && $0.hasValidEffort && abs($0.kg - kg) < 0.001 }
              }),
              history.prefix(2).allSatisfy({ $0.fromCompletePlan != false && ($0.plannedWorkingSets ?? workingSets) == workingSets }) else {
            return result(.insufficient, kg: kg, reps: target.minimum)
        }
        let latest = comparable[0]
        let recentMinimum = latest.map(\.reps).min() ?? target.minimum
        let nextReps = min(target.maximum, max(target.minimum, recentMinimum + (recentMinimum < target.maximum ? 1 : 0)))
        if target.loadKind == .bodyweight && kg == 0 {
            return result(.bodyweight, kg: kg, reps: nextReps)
        }
        let direction = target.loadKind == .assisted ? -1.0 : 1.0
        if latest.allSatisfy({ $0.reps >= target.maximum }) {
            if latest.contains(where: { ($0.rpe ?? 0) >= 9.5 || ($0.rir ?? 1) == 0 }) {
                return result(.highEffort, kg: kg, reps: target.maximum)
            }
            let increased = max(0, kg + direction * increment)
            if increased != kg { return result(.increase, kg: increased, reps: target.minimum) }
        }
        if comparable.allSatisfy({ $0.contains { $0.reps < target.minimum } }) {
            let reduced = max(0, kg - direction * increment)
            if reduced != kg { return result(.reduce, kg: reduced, reps: target.minimum) }
        }
        return result(.maintain, kg: kg, reps: nextReps)
    }
}
