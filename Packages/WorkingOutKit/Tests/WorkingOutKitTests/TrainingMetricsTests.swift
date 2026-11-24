import XCTest
@testable import WorkingOutKit

final class TrainingMetricsTests: XCTestCase {
    func testVolumeAndRecordsIgnoreInvalidAndIncompleteSets() {
        let sets = [
            TrainingSet(kilograms: 60, repetitions: 10, completed: true),
            TrainingSet(kilograms: 80, repetitions: 5, completed: true),
            TrainingSet(kilograms: 100, repetitions: 5, completed: false),
            TrainingSet(kilograms: -5, repetitions: 10, completed: true),
            TrainingSet(kilograms: .nan, repetitions: 10, completed: true),
            TrainingSet(kilograms: 200, repetitions: 0, completed: true)
        ]
        XCTAssertEqual(TrainingMetrics.volume(sets), 1000)
        XCTAssertEqual(TrainingMetrics.heaviestWeight(sets), 80)
        XCTAssertNil(TrainingMetrics.heaviestWeight([]))
        XCTAssertEqual(TrainingMetrics.volume([]), 0)
    }

    func testOneRepMax() {
        XCTAssertEqual(TrainingMetrics.estimatedOneRepMax(.init(kilograms: 100, repetitions: 1, completed: true)), 100)
        XCTAssertEqual(TrainingMetrics.estimatedOneRepMax(.init(kilograms: 90, repetitions: 10, completed: true)) ?? 0, 120, accuracy: 0.001)
        XCTAssertNil(TrainingMetrics.estimatedOneRepMax(.init(kilograms: 90, repetitions: 12, completed: true)))
        XCTAssertNil(TrainingMetrics.estimatedOneRepMax(.init(kilograms: 90, repetitions: 5, completed: false)))
    }

    func testRunningPace() {
        XCTAssertEqual(TrainingMetrics.runningPaceSeconds(duration: 1500, kilometers: 5), 300)
        XCTAssertEqual(TrainingMetrics.runningPaceSeconds(duration: 1503, kilometers: 5), 301)
        XCTAssertNil(TrainingMetrics.runningPaceSeconds(duration: 1500, kilometers: 0))
        XCTAssertNil(TrainingMetrics.runningPaceSeconds(duration: .infinity, kilometers: 5))
        XCTAssertNil(TrainingMetrics.runningPaceSeconds(duration: -1, kilometers: 5))
    }

    func testWeeklyGoal() {
        XCTAssertEqual(TrainingMetrics.weeklyProgress(completed: 2, goal: 4), 0.5)
        XCTAssertEqual(TrainingMetrics.weeklyProgress(completed: 5, goal: 4), 1)
        XCTAssertEqual(TrainingMetrics.weeklyProgress(completed: -1, goal: 4), 0)
        XCTAssertEqual(TrainingMetrics.weeklyProgress(completed: 1, goal: 0), 0)
    }
}
