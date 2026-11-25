import Foundation
import XCTest
@testable import WorkingOutKit

final class WorkoutLogTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000)

    func testLegacyWorkoutMigrationPreservesHistoryAndUserNames() throws {
        let fixture = """
        {
          "exercises": [{"id":"00000000-0000-0000-0000-000000000001","name":"Dion's lift","sets":[]}],
          "history": [{"id":"00000000-0000-0000-0000-000000000002","date":0,"exercises":[
            {"id":"00000000-0000-0000-0000-000000000003","name":"Bench Press","sets":[
              {"id":"00000000-0000-0000-0000-000000000004","kg":40,"reps":5,"done":true}
            ]}
          ]}]
        }
        """
        var log = try JSONDecoder().decode(StrengthLog.self, from: Data(fixture.utf8))
        log.migrateExerciseIDs(["Bench Press": "bench-press"])
        XCTAssertEqual(log.history.first?.exercises.first?.identity, "bench-press")
        XCTAssertEqual(log.history.first?.volume, 200)
        XCTAssertNil(log.history.first?.duration)
        XCTAssertEqual(log.exercises.first?.name, "Dion's lift")
        XCTAssertEqual(log.customExercises?.first?.id, log.exercises.first?.exerciseID)
        log.migrateExerciseIDs(["Bench Press": "bench-press"])
        XCTAssertEqual(log.customExercises?.count, 1)

        log.exercises[0].name = "Dion's renamed lift"
        XCTAssertEqual(log.previousSets(for: "bench-press").first?.kg, 40)
        let migrated = try JSONDecoder().decode(StrengthLog.self, from: JSONEncoder().encode(log))
        XCTAssertEqual(migrated.history.first?.exercises.first?.identity, "bench-press")
        XCTAssertEqual(migrated.history.first?.id.uuidString, "00000000-0000-0000-0000-000000000002")
    }

    func testRecoveryAndFinishAreOneSnapshot() throws {
        var log = StrengthLog()
        log.started = start
        log.paused = start.addingTimeInterval(90)
        log.pausedSeconds = 15
        log.notes = "Keep the original note"
        log.exercises = [
            StrengthExercise(name: "Bænkpres", exerciseID: "bench-press", sets: [
                StrengthSet(kg: 20, reps: 5, done: true, warmup: true),
                StrengthSet(kg: 40, reps: 8, done: true),
                StrengthSet(kg: 50, reps: 3),
                StrengthSet(kg: 55, reps: 0, done: true)
            ])
        ]
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("log.json")
        try JSONEncoder().encode(log).write(to: file, options: .atomic)
        var restored = try JSONDecoder().decode(StrengthLog.self, from: Data(contentsOf: file))
        let now = start.addingTimeInterval(200)
        XCTAssertTrue(restored.finish(at: now))
        XCTAssertFalse(restored.finish(at: now))
        XCTAssertTrue(restored.exercises.isEmpty)
        XCTAssertNil(restored.started)
        XCTAssertEqual(restored.history.count, 1)
        XCTAssertEqual(restored.history.first?.duration, 75)
        XCTAssertEqual(restored.history.first?.notes, log.notes)
        XCTAssertEqual(restored.history.first?.volume, 320)
        XCTAssertEqual(restored.history.first?.exercises.first?.sets.count, 2)
        XCTAssertEqual(TrainingMetrics.heaviestWeight(restored.bestSets(for: "bench-press")), 40)
    }

    func testProgramValidationAndRoundTrip() throws {
        var program = StrengthProgram()
        XCTAssertFalse(program.isValid)
        program.name = "Morgentræning"
        program.exercises = [.init(name: "Bænkpres", exerciseID: "bench-press")]
        XCTAssertTrue(program.isValid)
        program.restSeconds = 0
        XCTAssertFalse(program.isValid)
        program.restSeconds = 90
        program.exercises[0].sets[0].reps = 0
        XCTAssertFalse(program.isValid)
        program.exercises[0].sets[0].reps = 3
        let restored = try JSONDecoder().decode(StrengthProgram.self, from: JSONEncoder().encode(program))
        XCTAssertTrue(restored.isValid)
        XCTAssertEqual(restored.id, program.id)
        XCTAssertEqual(restored.name, program.name)
    }

    func testUnitConversionsPreserveCanonicalValues() {
        let kg = 72.5
        XCTAssertEqual(WeightUnit.lb.canonical(WeightUnit.lb.display(kg)), kg, accuracy: 0.000_001)
        XCTAssertEqual(DistanceUnit.mi.display(1_609.344), 1, accuracy: 0.000_001)
        XCTAssertEqual(DistanceUnit.km.display(1_609.344), 1.609344, accuracy: 0.000_001)
    }

    func testReconciliationUsesLinkedIDOrOwnSource() {
        let id = UUID()
        func matches(link: UUID?, source: Bool, duration: TimeInterval?, externalStart: Date = start) -> Bool {
            ActivityReconciliation.matches(
                localID: link, localStart: start, localDuration: duration, externalID: id,
                externalStart: externalStart, externalDuration: 300, isOwnSource: source
            )
        }
        XCTAssertTrue(matches(link: id, source: false, duration: nil))
        XCTAssertFalse(matches(link: UUID(), source: true, duration: 300))
        XCTAssertFalse(matches(link: nil, source: false, duration: 300))
        XCTAssertTrue(matches(link: nil, source: true, duration: 300))
        XCTAssertTrue(matches(link: nil, source: true, duration: nil, externalStart: start.addingTimeInterval(-300)))
    }

    func testDeletingStrengthLogTracksTheLinkedHealthWorkout() {
        var log = StrengthLog()
        var session = StrengthSession(exercises: [])
        session.healthID = UUID()
        log.history = [session]
        log.deleteSession(id: session.id)
        log.deleteSession(id: session.id)
        XCTAssertTrue(log.history.isEmpty)
        XCTAssertEqual(log.hiddenSyncIDs, [session.id])
        XCTAssertEqual(log.hiddenHealthIDs?.first, session.healthID)
    }

    func testDistanceRecordRequiresACompletedContinuousGPSRun() throws {
        var run = RunRecord(date: start)
        run.points = [
            RunPoint(latitude: 0, longitude: 0, elapsed: 20, meters: 0, newSegment: true),
            RunPoint(latitude: 0, longitude: 0, elapsed: 140, meters: 1_200, newSegment: false),
            RunPoint(latitude: 0, longitude: 0, elapsed: 200, meters: 1_200, newSegment: true),
            RunPoint(latitude: 0, longitude: 0, elapsed: 280, meters: 2_000, newSegment: false)
        ]
        XCTAssertNil(run.timeTo(meters: 1_000))
        run.finishDate = start.addingTimeInterval(300)
        XCTAssertEqual(try XCTUnwrap(run.timeTo(meters: 1_000)), 100, accuracy: 0.000_001)
        XCTAssertNil(run.timeTo(meters: 1_609.344))
        XCTAssertNil(run.timeTo(meters: .nan))
    }

    func testRunningSplitsInterpolateAndExcludePausedTime() throws {
        var run = RunRecord(date: start)
        XCTAssertNil(run.meters)
        XCTAssertTrue(run.splits(unit: .km).isEmpty)
        run.paused = start.addingTimeInterval(50)
        XCTAssertEqual(run.elapsed(at: start.addingTimeInterval(500)), 50)
        run.resume(at: start.addingTimeInterval(80))
        XCTAssertEqual(run.elapsed(at: start.addingTimeInterval(100)), 70)
        run.points = [(0, 0), (90, 900), (200, 900), (350, 2_400)].enumerated().map { index, sample in
            RunPoint(latitude: 0, longitude: 0, elapsed: Double(sample.0), meters: Double(sample.1), newSegment: index == 0 || index == 2)
        }
        XCTAssertEqual(run.splits(unit: .km), [210, 100])
        XCTAssertEqual(try XCTUnwrap(run.splits(unit: .mi).first), 270.9344, accuracy: 0.000_001)
        let restored = try JSONDecoder().decode(RunRecord.self, from: JSONEncoder().encode(run))
        XCTAssertEqual(restored.meters, 2_400)
    }
}
