import Foundation

public struct StrengthSet: Codable, Identifiable, Sendable {
    public var id = UUID()
    public var kg: Double
    public var reps: Int
    public var done: Bool
    public var warmup: Bool?
    public var rpe: Double?
    public var rir: Int?

    public init(kg: Double = 0, reps: Int = 10, done: Bool = false, warmup: Bool? = nil) {
        self.kg = kg
        self.reps = reps
        self.done = done
        self.warmup = warmup
    }

    public var hasValidEffort: Bool {
        (rpe.map { $0.isFinite && (1...10).contains($0) } ?? true) &&
            (rir.map { (0...20).contains($0) } ?? true)
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

    public var progression: ProgressionTarget?
    public var plannedWorkingSets: Int?
    public var restSeconds: Int?

    public var identity: String { exerciseID ?? "legacy:" + name }
}

public struct StrengthSession: Codable, Identifiable, Sendable {
    public var id = UUID()
    public var date: Date
    public var exercises: [StrengthExercise]
    public var duration: TimeInterval?
    public var notes: String?
    public var healthID: UUID?
    public var endDate: Date?
    public var occurrenceID: String?

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
    public var days: [TrainingDay]?

    public init() {}

    public var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            (15...600).contains(restSeconds) &&
            ((days?.isEmpty == false && days?.allSatisfy(\.isValid) == true) || (days?.isEmpty != false && Self.validExercises(exercises)))
    }

    static func validExercises(_ exercises: [StrengthExercise]) -> Bool {
        !exercises.isEmpty && exercises.allSatisfy { exercise in
            !exercise.sets.isEmpty && exercise.sets.contains { $0.warmup != true } &&
                (exercise.progression?.isValid ?? true) &&
                (exercise.restSeconds.map { (15...600).contains($0) } ?? true) &&
                exercise.sets.allSatisfy { $0.reps > 0 && $0.kg.isFinite && $0.kg >= 0 }
        }
    }
}

public struct StrengthLog: Codable, Sendable {
    public var exercises: [StrengthExercise] = []
    public var history: [StrengthSession] = []
    public var programs: [StrengthProgram]?
    public var runs: [RunRecord]?
    public var activeRun: RunRecord?
    public var scheduleOverrides: [ScheduledWorkout]?
    public var activeOccurrenceID: String?
    public var activeProgramID: UUID?
    public var hiddenHealthIDs: [UUID]?
    public var hiddenSyncIDs: [UUID]?
    public var customExercises: [CustomExercise]?
    public var started: Date?
    public var paused: Date?
    public var pausedSeconds: TimeInterval?
    public var restUntil: Date?
    public var activeRestSeconds: Int?
    public var notes: String?

    public init() {}

    public mutating func migrateExerciseIDs(_ legacyCatalog: [String: String]) {
        var custom = customExercises ?? []
        func migrate(_ exercises: inout [StrengthExercise]) {
            for index in exercises.indices where exercises[index].exerciseID == nil {
                let name = exercises[index].name
                if let known = legacyCatalog[name] {
                    exercises[index].exerciseID = known
                } else {
                    let id = "legacy:" + name
                    exercises[index].exerciseID = id
                    if !custom.contains(where: { $0.id == id }) {
                        custom.append(CustomExercise(id: id, name: name))
                    }
                }
            }
        }
        migrate(&exercises)
        for index in history.indices { migrate(&history[index].exercises) }
        customExercises = custom
    }

    public mutating func deleteSession(id: UUID) {
        guard let session = history.first(where: { $0.id == id }) else { return }
        history.removeAll { $0.id == id }
        hiddenSyncIDs = (hiddenSyncIDs ?? []) + [id]
        if let healthID = session.healthID {
            hiddenHealthIDs = (hiddenHealthIDs ?? []) + [healthID]
        }
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
        var session = StrengthSession(date: started ?? date, exercises: completed, duration: elapsed(at: date), notes: notes)
        session.endDate = date
        session.occurrenceID = activeOccurrenceID
        history.append(session)
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
        activeOccurrenceID = nil
        activeProgramID = nil
        notes = nil
    }

    public func progressionHistory(for identity: String) -> [StrengthExercise] {
        history.sorted { $0.date > $1.date }.compactMap { session in
            session.exercises.first { $0.identity == identity }
        }
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
