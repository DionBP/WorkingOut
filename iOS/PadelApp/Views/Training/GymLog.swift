import SwiftUI
import UserNotifications
import WorkingOutKit

@MainActor
final class GymLog: ObservableObject {
    @Published private(set) var log = StrengthLog()
    @Published private(set) var inaccessible = false
    @Published var storageError = false
    private let url = URL.documentsDirectory.appendingPathComponent("workingout-gym-v1.json")
    private static let restNotification = "workingout.rest"

    init() {
        do {
            let data = try Data(contentsOf: url)
            log = try JSONDecoder().decode(StrengthLog.self, from: data)
            log.migrateExerciseIDs(ExerciseCatalog.legacyIDs)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            // First launch.
        } catch {
            inaccessible = true
            storageError = true
        }
    }

    func binding<Value>(_ path: WritableKeyPath<StrengthLog, Value>) -> Binding<Value> {
        Binding(get: { self.log[keyPath: path] }, set: { value in
            self.update { $0[keyPath: path] = value }
        })
    }

    @discardableResult
    func update(_ change: (inout StrengthLog) -> Void) -> Bool {
        guard !inaccessible else { storageError = true; return false }
        var next = log
        change(&next)
        do {
            let data = try JSONEncoder().encode(next)
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            log = next
            return true
        } catch {
            storageError = true
            return false
        }
    }

    @discardableResult
    func start(program: StrengthProgram? = nil, day: TrainingDay? = nil, occurrence: ProgramOccurrence? = nil) -> Bool {
        guard log.started == nil, program == nil || log.exercises.isEmpty else { return false }
        if let occurrence, log.history.contains(where: { $0.occurrenceID == occurrence.id }) { return false }
        return update { log in
            log.started = .now
            if let program {
                log.notes = program.notes
                log.activeProgramID = program.id
                log.activeOccurrenceID = occurrence?.id
                log.activeRestSeconds = day?.restSeconds ?? program.restSeconds
                log.exercises = (day?.exercises ?? program.exercises).map { target in
                    let previous = log.previousSets(for: target.identity)
                    let previousWorking = previous.filter { $0.warmup != true }
                    let required = target.sets.filter { $0.warmup != true }.count
                    let previousLoad = previousWorking.first?.kg
                    let useLastLoad = target.progression?.strategy == .doubleProgression &&
                        target.progression?.useLastLoad == true && previousWorking.count == required &&
                        previousWorking.allSatisfy { $0.kg == previousLoad }
                    var exercise = target
                    exercise.id = UUID()
                    exercise.plannedWorkingSets = required
                    exercise.sets = target.sets.enumerated().map { index, set in
                        let prefill = previous.indices.contains(index) ? previous[index].kg : 0
                        let base = target.progression != nil || set.kg > 0 ? set.kg : prefill
                        let weight = useLastLoad && set.warmup != true ? (previousLoad ?? base) : base
                        return StrengthSet(kg: weight, reps: set.reps, warmup: set.warmup)
                    }
                    return exercise
                }
            }
        }
    }

    func recommendation(for exercise: StrengthExercise) -> ProgressionRecommendation? {
        guard let target = exercise.progression,
              let next = exercise.sets.first(where: { !$0.done && $0.warmup != true }) else { return nil }
        return DoubleProgression.recommend(target: target,
            workingSets: exercise.plannedWorkingSets ?? exercise.sets.filter { $0.warmup != true }.count,
            kg: next.kg, equipment: ExerciseCatalog.byID[exercise.identity]?.equipment,
            history: log.progressionHistory(for: exercise.identity))
    }

    func changeSchedule(_ workout: ProgramOccurrence, date: Date, skip: Bool) {
        update { log in
            var overrides = log.scheduleOverrides ?? []
            overrides.removeAll {
                $0.programID == workout.program.id && $0.dayID == workout.day.id && $0.originalDay == workout.originalDay
            }
            var change = ScheduledWorkout(programID: workout.program.id, dayID: workout.day.id, date: workout.originalDate, originalDay: workout.originalDay)
            change.date = date
            change.skipped = skip
            overrides.append(change)
            log.scheduleOverrides = overrides
        }
    }


    func add(_ exercise: StrengthExercise) {
        let previous = log.previousSets(for: exercise.identity)
        let sets = previous.isEmpty ? exercise.sets : previous.map {
            StrengthSet(kg: $0.kg, reps: $0.reps, warmup: $0.warmup)
        }
        update { $0.exercises.append(StrengthExercise(name: exercise.name, exerciseID: exercise.exerciseID, sets: sets)) }
    }

    func pauseOrResume(at date: Date = .now) {
        guard log.started != nil else { return }
        update { log in
            if let paused = log.paused {
                log.pausedSeconds = (log.pausedSeconds ?? 0) + max(0, date.timeIntervalSince(paused))
                log.paused = nil
            } else {
                log.paused = date
            }
        }
    }

    func finish() -> StrengthSession? {
        guard log.exercises.contains(where: { $0.sets.contains(where: { $0.metric.isValid }) }) else { return nil }
        guard update({ $0.finish(at: .now) }) else { return nil }
        cancelRestNotification()
        return log.history.last
    }

    func discard() {
        if update({ $0.discard() }) { cancelRestNotification() }
    }

    func complete(exerciseID: UUID, setID: UUID, seconds: Int, message: String) {
        guard log.paused == nil,
              let exercise = log.exercises.firstIndex(where: { $0.id == exerciseID }),
              let set = log.exercises[exercise].sets.firstIndex(where: { $0.id == setID }) else { return }
        let value = log.exercises[exercise].sets[set]
        guard value.kg.isFinite, value.kg >= 0, value.reps > 0, value.hasValidEffort else { return }
        guard update({ log in
            log.exercises[exercise].sets[set].done.toggle()
            if !value.done {
                log.started = log.started ?? .now
                log.restUntil = Date.now.addingTimeInterval(Double(seconds))
            }
        }), !value.done else { return }
        cancelRestNotification()
        let content = UNMutableNotificationContent()
        content.body = message
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(seconds), repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: Self.restNotification, content: content, trigger: trigger), withCompletionHandler: nil)
    }

    func skipRest() {
        if update({ $0.restUntil = nil }) { cancelRestNotification() }
    }

    private func cancelRestNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.restNotification])
    }
}
