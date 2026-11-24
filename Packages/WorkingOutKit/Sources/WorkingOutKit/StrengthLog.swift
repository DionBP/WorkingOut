import Foundation

public struct StrengthSet: Codable, Identifiable, Sendable {
    public var id = UUID()
    public var kg: Double
    public var reps: Int
    public var done: Bool
    public var warmup: Bool?

    public init(kg: Double = 0, reps: Int = 10, done: Bool = false, warmup: Bool? = nil) {
        self.kg = kg
        self.reps = reps
        self.done = done
        self.warmup = warmup
    }

    public var metric: TrainingSet {
        TrainingSet(kilograms: kg, repetitions: reps, completed: done)
    }
}

public struct StrengthExercise: Codable, Identifiable, Sendable {
    public var id = UUID()
    public var name: String
    public var exerciseID: String?
    public var sets: [StrengthSet]

    public init(name: String, exerciseID: String? = nil, sets: [StrengthSet] = [StrengthSet(), StrengthSet(), StrengthSet()]) {
        self.name = name
        self.exerciseID = exerciseID
        self.sets = sets
    }

    public var identity: String { exerciseID ?? "legacy:" + name }
}

public struct StrengthSession: Codable, Identifiable, Sendable {
    public var id = UUID()
    public var date: Date
    public var exercises: [StrengthExercise]
    public var duration: TimeInterval?
    public var notes: String?
    public var healthID: UUID?

    public init(date: Date = Date(), exercises: [StrengthExercise], duration: TimeInterval? = nil, notes: String? = nil) {
        self.date = date
        self.exercises = exercises
        self.duration = duration
        self.notes = notes
    }

    public var volume: Double {
        TrainingMetrics.volume(exercises.flatMap(\.sets).filter { $0.warmup != true }.map(\.metric))
    }
}

public struct CustomExercise: Codable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var instructions: String

    public init(id: String = UUID().uuidString, name: String, instructions: String = "") {
        self.id = id
        self.name = name
        self.instructions = instructions
    }
}

public struct StrengthProgram: Codable, Identifiable, Sendable {
    public var id = UUID()
    public var name = ""
    public var exercises: [StrengthExercise] = []
    public var restSeconds = 90
    public var notes = ""

    public init() {}

    public var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            (15...600).contains(restSeconds) && !exercises.isEmpty &&
            exercises.allSatisfy { !$0.sets.isEmpty && $0.sets.allSatisfy { $0.reps > 0 && $0.kg.isFinite && $0.kg >= 0 } }
    }
}

public struct StrengthLog: Codable, Sendable {
    public var exercises: [StrengthExercise] = []
    public var history: [StrengthSession] = []
    public var programs: [StrengthProgram]?
    public var runs: [RunRecord]?
    public var activeRun: RunRecord?
    public var customExercises: [CustomExercise]?
    public var started: Date?
    public var paused: Date?
    public var pausedSeconds: TimeInterval?
    public var restUntil: Date?
    public var activeRestSeconds: Int?
    public var notes: String?

    public init() {}

    public mutating func migrateExerciseIDs(_ legacyCatalog: [String: String]) {
        func migrate(_ exercises: inout [StrengthExercise]) {
            for index in exercises.indices where exercises[index].exerciseID == nil {
                exercises[index].exerciseID = legacyCatalog[exercises[index].name]
            }
        }
        migrate(&exercises)
        for index in history.indices { migrate(&history[index].exercises) }
    }

    public func elapsed(at date: Date) -> TimeInterval? {
        started.map { max(0, (paused ?? date).timeIntervalSince($0) - (pausedSeconds ?? 0)) }
    }

    @discardableResult
    public mutating func finish(at date: Date) -> Bool {
        let completed = exercises.compactMap { exercise -> StrengthExercise? in
            var copy = exercise
            copy.sets = copy.sets.filter { $0.metric.isValid }
            return copy.sets.isEmpty ? nil : copy
        }
        guard !completed.isEmpty else { return false }
        history.append(StrengthSession(date: started ?? date, exercises: completed, duration: elapsed(at: date), notes: notes))
        discard()
        return true
    }

    public mutating func discard() {
        exercises = []
        started = nil
        paused = nil
        pausedSeconds = nil
        restUntil = nil
        activeRestSeconds = nil
        notes = nil
    }

    public func previousSets(for identity: String) -> [StrengthSet] {
        history.reversed().lazy.compactMap { session in
            session.exercises.first { $0.identity == identity }?.sets.filter { $0.metric.isValid }
        }.first ?? []
    }

    public func bestSets(for identity: String) -> [TrainingSet] {
        history.flatMap(\.exercises).filter { $0.identity == identity }
            .flatMap(\.sets).filter { $0.warmup != true && $0.kg > 0 }.map(\.metric)
    }
}

public enum WeightUnit: String, CaseIterable, Identifiable, Sendable {
    case kg, lb
    public var id: Self { self }

    public func display(_ kilograms: Double) -> Double {
        self == .kg ? kilograms : kilograms / 0.45359237
    }

    public func canonical(_ value: Double) -> Double {
        self == .kg ? value : value * 0.45359237
    }
}

public enum DistanceUnit: String, CaseIterable, Identifiable, Sendable {
    case km, mi
    public var id: Self { self }

    public func display(_ meters: Double) -> Double {
        meters / (self == .km ? 1_000 : 1_609.344)
    }
}

public enum ActivityReconciliation {
    public static func matches(
        localID: UUID?, localStart: Date, localDuration: TimeInterval?, externalID: UUID,
        externalStart: Date, externalDuration: TimeInterval, isOwnSource: Bool
    ) -> Bool {
        if let localID { return localID == externalID }
        // Legacy logs have no start or duration. Their date was recorded at finish.
        guard isOwnSource else { return false }
        if let localDuration {
            return abs(externalStart.timeIntervalSince(localStart)) <= 2 &&
                abs(externalDuration - localDuration) <= 2
        }
        return abs(externalStart.addingTimeInterval(externalDuration).timeIntervalSince(localStart)) <= 5
    }
}
