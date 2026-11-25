import XCTest
@testable import WorkingOutKit

final class ProgressionTests: XCTestCase {
    private func lift(_ reps: [Int], kg: Double = 40) -> StrengthExercise {
        StrengthExercise(name: "Bench Press", exerciseID: "bench-press",
                         sets: reps.map { StrengthSet(kg: kg, reps: $0, done: true) })
    }

    private func recommend(_ exercises: [StrengthExercise], target: ProgressionTarget = .init(),
                           kg: Double = 40) -> ProgressionRecommendation? {
        DoubleProgression.recommend(target: target, workingSets: 3, kg: kg, equipment: "dumbbells", history: exercises)
    }

    func testTopOfRangeIncreasesOnlyAfterComparableHistory() {
        let high = lift([12, 12, 12])
        let result = recommend([high, lift([10, 9, 9])])
        XCTAssertEqual(result?.reason, .increase)
        XCTAssertEqual(result?.kg, 41)
        XCTAssertEqual(result?.reps, 8)
        XCTAssertEqual(recommend([high])?.reason, .insufficient)
        XCTAssertEqual(recommend([high, lift([12, 12, 12], kg: 25)])?.reason, .insufficient)
    }

    func testIncompleteAndMissingWorkDoNotIncreaseLoad() {
        let high = lift([12, 12, 12])
        var partial = high
        partial.sets[2].done = false
        XCTAssertEqual(recommend([partial, high])?.reason, .insufficient)
        partial = high
        partial.plannedWorkingSets = 4
        XCTAssertEqual(recommend([partial, high])?.reason, .insufficient)
        partial = high
        partial.fromCompletePlan = false
        XCTAssertEqual(recommend([partial, high])?.reason, .insufficient)
        XCTAssertEqual(recommend([])?.reason, .insufficient)
    }

    func testMissedTargetsAndPlateaus() {
        let miss = lift([8, 8, 7])
        XCTAssertEqual(recommend([miss, miss])?.reason, .reduce)
        XCTAssertEqual(recommend([miss, miss])?.kg, 39)
        XCTAssertEqual(recommend([miss, lift([9, 9, 9])])?.reason, .maintain)
        XCTAssertEqual(recommend([lift([10, 9, 9]), lift([10, 9, 9])])?.reps, 10)
    }

    func testEffortAndAssistanceChangeRecommendation() {
        var high = lift([12, 12, 12])
        high.sets[0].rir = 0
        XCTAssertEqual(recommend([high, lift([9, 9, 9])])?.reason, .highEffort)
        var target = ProgressionTarget()
        target.loadKind = .assisted
        target.incrementKg = 5
        XCTAssertEqual(recommend([lift([12, 12, 12]), lift([9, 9, 9])], target: target)?.kg, 35)
        XCTAssertEqual(recommend([lift([7, 7, 7]), lift([7, 7, 7])], target: target)?.kg, 45)
        target.loadKind = .bodyweight
        let bodyweight = [lift([12, 12, 12], kg: 0), lift([10, 10, 10], kg: 0)]
        XCTAssertEqual(recommend(bodyweight, target: target, kg: 0)?.reason, .bodyweight)
        XCTAssertNil(recommend(bodyweight, target: target, kg: 0)?.estimatedMaxKg)
    }

    func testInvalidInputsAndManualOverride() {
        var manual = ProgressionTarget()
        manual.strategy = .manual
        XCTAssertEqual(recommend([], target: manual)?.reason, .manual)
        manual.minimum = 13
        XCTAssertNil(recommend([], target: manual))
        XCTAssertNil(recommend([], kg: .infinity))
        var invalidEffort = lift([12, 12, 12])
        invalidEffort.sets[0].rpe = 20
        XCTAssertEqual(recommend([invalidEffort, lift([10, 10, 10])])?.reason, .insufficient)
    }
}
