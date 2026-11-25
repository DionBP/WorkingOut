#if DEBUG && targetEnvironment(simulator)
import Foundation
import WorkingOutKit

enum TrainingScreenshotFixtures {
    static var enabled: Bool {
        ProcessInfo.processInfo.environment["WORKINGOUT_SCREENSHOTS"] == "1"
    }

    static var screen: String? {
        enabled ? ProcessInfo.processInfo.environment["WORKINGOUT_SCREEN"] : nil
    }

    static func log(calendar: Calendar = .current, now: Date = .now) -> StrengthLog {
        func exercise(_ id: String, _ name: String, kg: Double, reps: Int, done: Bool = false) -> StrengthExercise {
            var result = StrengthExercise(name: name, exerciseID: id, sets: (0..<3).map { _ in
                StrengthSet(kg: kg, reps: reps, done: done)
            })
            result.progression = ProgressionTarget()
            return result
        }
        var program = StrengthProgram()
        program.name = "Upper body"
        var day = TrainingDay()
        day.name = "Pull & press"
        day.weekday = calendar.component(.weekday, from: now)
        day.exercises = [exercise("lat-pulldown", "Lat Pulldown", kg: 45, reps: 10),
                         exercise("bench-press", "Bench Press", kg: 62.5, reps: 10),
                         exercise("hammer-curl", "Hammer Curl", kg: 14, reps: 12)]
        var next = TrainingDay()
        next.name = "Lower body"
        next.weekday = day.weekday % 7 + 1
        next.exercises = [exercise("goblet-squat", "Goblet Squat", kg: 26, reps: 12),
                          exercise("bulgarian-split-squat", "Bulgarian Split Squat", kg: 18, reps: 10)]
        program.days = [day, next]
        var log = StrengthLog()
        log.programs = [program]
        log.history = [1, 4, 12, 20, 35, 54, 74, 90, 128, 156, 190, 225].enumerated().reversed().compactMap { index, days in
            guard let date = calendar.date(byAdding: .day, value: -days, to: now) else { return nil }
            return StrengthSession(date: date, exercises: [
                exercise("lat-pulldown", "Lat Pulldown", kg: 45, reps: index == 0 ? 12 : 10, done: true),
                exercise("bench-press", "Bench Press", kg: 62.5 - Double(index) * 2.5, reps: 10, done: true)
            ], duration: Double(2_400 + index * 60))
        }
        log.runs = [2, 12, 36, 52, 78, 110, 145].enumerated().compactMap { index, days in
            guard let date = calendar.date(byAdding: .day, value: -days, to: now) else { return nil }
            let distance = Double(6_600 - index * 400)
            let elapsed = distance * 0.33
            var run = RunRecord(date: date)
            run.finishDate = date.addingTimeInterval(elapsed)
            run.points = [
                .init(latitude: 55.68, longitude: 12.57, elapsed: 0, meters: 0, newSegment: true),
                .init(latitude: 55.70, longitude: 12.62, elapsed: elapsed, meters: distance, newSegment: false)
            ]
            return run
        }
        return log
    }
}
#endif
