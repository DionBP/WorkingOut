import Foundation

public struct TrainingDay: Codable, Identifiable, Sendable {
    public var id = UUID()
    public var name = ""
    public var weekday = 2
    public var exercises: [StrengthExercise] = []
    public var restSeconds = 90

    public init() {}

    public var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            (1...7).contains(weekday) && (15...600).contains(restSeconds) &&
            StrengthProgram.validExercises(exercises)
    }
}

public struct ScheduledWorkout: Codable, Identifiable, Sendable {
    public let id: UUID
    public let programID: UUID
    public let dayID: UUID
    public let originalDate: Date
    public let originalDay: String
    public var date: Date
    public var skipped = false

    public init(programID: UUID, dayID: UUID, date: Date, originalDay: String) {
        id = UUID()
        self.programID = programID
        self.dayID = dayID
        originalDate = date
        self.originalDay = originalDay
        self.date = date
    }
}

public struct ProgramOccurrence: Identifiable, Sendable {
    public var id: String {
        "\(program.id.uuidString):\(day.id.uuidString):\(originalDay)"
    }
    public let program: StrengthProgram
    public let day: TrainingDay
    public let originalDate: Date
    public let originalDay: String
    public let date: Date
}

public enum ProgramSchedule {
    public static func occurrences(programs: [StrengthProgram], overrides: [ScheduledWorkout], in interval: DateInterval,
                                   calendar: Calendar) -> [ProgramOccurrence] {
        var result: [ProgramOccurrence] = []
        let valid = programs.filter(\.isValid)
        var civilCalendar = Calendar(identifier: .gregorian)
        civilCalendar.timeZone = calendar.timeZone
        func dayKey(_ date: Date) -> String {
            let parts = civilCalendar.dateComponents([.year, .month, .day], from: date)
            return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
        }
        var date = calendar.startOfDay(for: interval.start)
        while date < interval.end {
            let key = dayKey(date)
            for program in valid {
                for day in program.days ?? [] where day.weekday == calendar.component(.weekday, from: date) {
                    let overridden = overrides.contains {
                        $0.programID == program.id && $0.dayID == day.id && $0.originalDay == key
                    }
                    if !overridden && date >= interval.start {
                        result.append(ProgramOccurrence(program: program, day: day, originalDate: date, originalDay: key, date: date))
                    }
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: date), next > date else { break }
            date = next
        }
        for override in overrides where !override.skipped && override.date >= interval.start && override.date < interval.end {
            guard let program = valid.first(where: { $0.id == override.programID }),
                  let day = program.days?.first(where: { $0.id == override.dayID }) else { continue }
            result.append(ProgramOccurrence(program: program, day: day, originalDate: override.originalDate, originalDay: override.originalDay, date: override.date))
        }
        return result.sorted { $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date }
    }
}
