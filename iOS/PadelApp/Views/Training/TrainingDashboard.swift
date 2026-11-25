import SwiftUI
import HealthKit
import WorkingOutKit

struct TrainingActivity: Identifiable {
    let id: UUID
    let date: Date
    let duration: TimeInterval?
    let running: Bool
    var meters: Double?
    var energy: Double?
    var heartRate: Double?
    var source: String?
    var strength: StrengthSession?
    var run: RunRecord?

    static func list(local: [StrengthSession], runs: [RunRecord], external: [HKWorkout]) -> [Self] {
        let strength = local.map { Self(id: $0.id, date: $0.date, duration: $0.duration, running: false, strength: $0) }
        let imported = external.map { workout in
            Self(id: workout.uuid, date: workout.startDate, duration: workout.duration,
                 running: workout.workoutActivityType == .running,
                 meters: (workout.statistics(for: HKQuantityType(.distanceWalkingRunning))?.sumQuantity() ?? workout.totalDistance)?
                    .doubleValue(for: .meter()),
                 energy: (workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity() ?? workout.totalEnergyBurned)?
                    .doubleValue(for: .kilocalorie()),
                 heartRate: workout.statistics(for: HKQuantityType(.heartRate))?.averageQuantity()?
                    .doubleValue(for: HKUnit.count().unitDivided(by: .minute())),
                 source: workout.sourceRevision.source.name)
        }
        let running = runs.map { run in
            Self(id: run.id, date: run.date, duration: run.elapsed(at: run.finishDate ?? run.date),
                 running: true, meters: run.meters, run: run)
        }
        return (strength + running + imported).sorted { $0.date > $1.date }
    }
}

struct ActivityRow: View {
    var activity: TrainingActivity
    var display: TrainingPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(display.text(activity.running ? "running" : "strength"),
                  systemImage: activity.running ? "figure.run" : "dumbbell")
                .font(.headline)
            Text(activity.date.formatted(.dateTime.day().month().year().locale(display.locale)))
            if let source = activity.source { Text(source) }
            if let duration = activity.duration { Text(display.duration(duration)) }
            if activity.running, let meters = activity.meters {
                Text("\(display.text(activity.run == nil ? "importedDistance" : "gpsDistance")) · \(display.distanceText(meters))")
                if let duration = activity.duration,
                   let pace = TrainingMetrics.runningPaceSeconds(duration: duration, kilometers: display.distance.display(meters)) {
                    Text("\(display.duration(Double(pace))) / \(display.distance.rawValue)")
                }
            }
            if let energy = activity.energy { Text("\(display.number(energy, precision: 0)) kcal") }
        }.font(.subheadline)
    }
}


private struct TrainingActivityDestination: View {
    let activity: TrainingActivity
    let gym: GymLog
    let health: TrainingStore
    let display: TrainingPresentation

    var body: some View {
        if let session = activity.strength {
            StrengthHistoryDetail(gym: gym, display: display, id: session.id)
        } else if let run = activity.run {
            List {
                RunMetrics(run: run, date: run.finishDate ?? run.date, display: display)
                RunRoute(run: run, display: display)
            }.navigationTitle(display.text("running"))
        } else {
            ImportedWorkoutDetail(activity: activity, display: display, health: health)
        }
    }
}

struct TrainingActivityLink: View {
    let activity: TrainingActivity
    let gym: GymLog
    let health: TrainingStore
    let display: TrainingPresentation

    var body: some View {
        NavigationLink {
            TrainingActivityDestination(activity: activity, gym: gym, health: health, display: display)
        } label: {
            HStack(spacing: 13) {
                Image(systemName: activity.running ? "figure.run" : "dumbbell.fill")
                    .frame(width: 42, height: 42)
                    .background(TrainingDesign.subdued, in: RoundedRectangle(cornerRadius: 11))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(display.text(activity.running ? "running" : "strength")).font(.headline)
                    Text(activity.date.formatted(.dateTime.day().month().year().locale(display.locale)))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if let meters = activity.meters, activity.running {
                    Text(display.distanceText(meters)).font(.subheadline.weight(.semibold))
                } else if let duration = activity.duration {
                    Text(display.duration(duration)).font(.subheadline.weight(.semibold))
                }
                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary).accessibilityHidden(true)
            }
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct StrengthRecord: Identifiable {
    let exercise: StrengthExercise
    let activity: TrainingActivity
    let load: Double
    var id: String { exercise.identity }

    static func best(in activities: [TrainingActivity]) -> [Self] {
        var records: [String: Self] = [:]
        for activity in activities {
            for exercise in activity.strength?.exercises ?? [] where exercise.progression?.loadKind != .assisted {
                let sets = exercise.sets.filter { $0.warmup != true && $0.kg > 0 }
                guard let load = TrainingMetrics.heaviestWeight(sets.map(\.metric)),
                      load > (records[exercise.identity]?.load ?? 0) else { continue }
                records[exercise.identity] = Self(exercise: exercise, activity: activity, load: load)
            }
        }
        return records.values.sorted {
            $0.load == $1.load ? $0.id < $1.id : $0.load > $1.load
        }
    }
}

struct TrainingRecordLink: View {
    let title: String
    let value: String
    let activity: TrainingActivity
    let gym: GymLog
    let health: TrainingStore
    let display: TrainingPresentation

    var body: some View {
        NavigationLink {
            TrainingActivityDestination(activity: activity, gym: gym, health: health, display: display)
        } label: {
            HStack {
                Image(systemName: "medal").accessibilityHidden(true)
                Text(title).font(.headline)
                Spacer(minLength: 8)
                Text(value).font(.subheadline.weight(.semibold)).monospacedDigit()
                Image(systemName: "chevron.right").font(.caption).accessibilityHidden(true)
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
