import Foundation
import XCTest
@testable import WorkingOutKit

final class WearableWorkoutTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 200)

    private func plan() -> WearablePlan {
        var exercise = StrengthExercise(name: "Bænkpres", exerciseID: "bench-press", sets: [
            StrengthSet(kg: 30, reps: 8, warmup: true), StrengthSet(kg: 50, reps: 8)
        ])
        exercise.progression = ProgressionTarget()
        return WearablePlan(id: "test-day", programID: UUID(), title: "Push", scheduledFor: start,
                            exercises: [WearableExercise(exercise: exercise, previous: [], recommendation: nil, restSeconds: 45)])
    }

    func testOfflineWorkoutResumesAndKeepsIdentityAcrossDelivery() throws {
        var record = WearableWorkout(plan: plan(), now: start)
        record.completeSet(at: start)
        XCTAssertEqual(record.restUntil, start.addingTimeInterval(45))
        record.completeSet(at: start.addingTimeInterval(10))
        XCTAssertEqual(record.setIndex, 1)
        record.togglePause(at: start.addingTimeInterval(20))
        record = try JSONDecoder().decode(WearableWorkout.self, from: JSONEncoder().encode(record))
        XCTAssertEqual(record.setIndex, 1)
        XCTAssertEqual(record.paused, start.addingTimeInterval(20))
        record.togglePause(at: start.addingTimeInterval(50))
        record.adjustCurrent(kg: 52.5, reps: 9)
        record.completeSet(at: start.addingTimeInterval(50))
        let result = try XCTUnwrap(record.finish(at: start.addingTimeInterval(60)))
        XCTAssertEqual(result.id, record.id)
        XCTAssertEqual(result.duration, 30)
        XCTAssertEqual(result.occurrenceID, "test-day")
        XCTAssertEqual(result.exercises.first?.sets.last?.kg, 52.5)
        XCTAssertNil(record.finish(at: start.addingTimeInterval(60)))

        var phone = StrengthLog()
        XCTAssertTrue(phone.receiveWearableSession(result))
        phone = try JSONDecoder().decode(StrengthLog.self, from: JSONEncoder().encode(phone))
        XCTAssertFalse(phone.receiveWearableSession(result))
        phone.deleteSession(id: result.id)
        XCTAssertFalse(phone.receiveWearableSession(result))
        XCTAssertTrue(phone.history.isEmpty)
    }

    func testReplacingAfterCompletedSetRetainsTheOriginalSet() throws {
        let plan = plan()
        var record = WearableWorkout(plan: plan, now: start)
        record.completeSet(at: start)
        record.replaceExercise(with: try XCTUnwrap(plan.exercises.first))
        XCTAssertEqual(record.exerciseIndex, 1)
        XCTAssertEqual(record.setIndex, 0)
        XCTAssertEqual(record.exercises[0].exercise.sets[0].done, true)
        XCTAssertEqual(record.exercises[1].exercise.sets[0].done, false)
    }

    func testProviderDraftPreservesOrderAndReportsUnmappedExercises() {
        let plan = plan()
        let unresolved = StructuredWorkoutDraft(plan: plan, exerciseCodes: [:])
        let mapped = StructuredWorkoutDraft(plan: plan, exerciseCodes: ["bench-press": "approved-code"])
        XCTAssertEqual(unresolved.unresolvedExercises, ["bench-press"])
        XCTAssertTrue(mapped.unresolvedExercises.isEmpty)
        XCTAssertEqual(mapped.scheduledFor, plan.scheduledFor)
        XCTAssertEqual(mapped.steps.map(\.warmup), [true, false])
        XCTAssertEqual(mapped.steps.map(\.maximumReps), [8, 12])
        XCTAssertEqual(mapped.steps.map(\.kilograms), [30, 50])
        XCTAssertEqual(mapped.steps.map(\.restSeconds), [45, 45])
    }
}
