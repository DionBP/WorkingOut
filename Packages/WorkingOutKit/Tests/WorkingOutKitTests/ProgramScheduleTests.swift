import Foundation
import XCTest
@testable import WorkingOutKit

final class ProgramScheduleTests: XCTestCase {
    func testRecurringPlanReschedulesAndSkipsWithoutDuplicating() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        calendar.firstWeekday = 2
        let monday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 23)))
        let week = try XCTUnwrap(calendar.dateInterval(of: .weekOfYear, for: monday))
        var program = StrengthProgram()
        program.name = "Training"
        var day = TrainingDay()
        day.name = "Push"
        day.weekday = 2
        day.exercises = [StrengthExercise(name: "Bench Press", exerciseID: "bench-press")]
        program.days = [day]
        XCTAssertTrue(program.isValid)
        let planned = try XCTUnwrap(ProgramSchedule.occurrences(programs: [program], overrides: [], in: week, calendar: calendar).first)
        XCTAssertEqual(planned.date, monday)
        var override = ScheduledWorkout(programID: program.id, dayID: day.id, date: monday, originalDay: planned.originalDay)
        override.date = monday.addingTimeInterval(86_400)
        let rescheduled = ProgramSchedule.occurrences(programs: [program], overrides: [override], in: week, calendar: calendar)
        XCTAssertEqual(rescheduled.map(\.id), [planned.id])
        XCTAssertEqual(rescheduled.first?.date, override.date)
        override.skipped = true
        XCTAssertTrue(ProgramSchedule.occurrences(programs: [program], overrides: [override], in: week, calendar: calendar).isEmpty)
    }
}
