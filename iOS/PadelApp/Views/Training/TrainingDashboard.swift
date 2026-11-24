import SwiftUI
import HealthKit
import Charts
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

struct TrainingAction: View {
    var title: String
    var icon: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).foregroundStyle(TrainingDesign.lime).accessibilityHidden(true)
            Text(title).font(.title3.bold())
            Spacer()
            Image(systemName: "chevron.right").font(.footnote).accessibilityHidden(true)
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(minHeight: 66)
        .background(TrainingDesign.charcoal, in: RoundedRectangle(cornerRadius: 22))
    }
}

struct TrainingOverview: View {
    var display: TrainingPresentation
    var calendar: Calendar
    var activities: [TrainingActivity]
    var goal: Int
    var activeStrength: Bool
    var activeRun: Bool
    var openStrength: () -> Void
    var openRun: () -> Void
    var openPrograms: () -> Void

    var body: some View {
        let interval = calendar.dateInterval(of: .weekOfYear, for: .now)
        let week = activities.filter { interval?.contains($0.date) == true }
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    Image("WorkingOutLogo").resizable().scaledToFit()
                        .frame(width: 52, height: 52).clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityHidden(true)
                    Text("WorkingOut").font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                }
                TrainingDesign.card {
                    Label(display.text("weeklyGoal"), systemImage: "target").font(.headline)
                    Text("\(week.count) / \(goal)").font(.system(.largeTitle, design: .rounded, weight: .bold))
                    ProgressView(value: TrainingMetrics.weeklyProgress(completed: week.count, goal: goal))
                        .tint(.primary).accessibilityLabel(display.text("weeklyGoal"))
                    if let start = interval?.start { weekCalendar(start: start, week: week) }
                    if !week.isEmpty { weeklyMetrics(week) }
                }
                Button(action: openStrength) {
                    TrainingAction(title: display.text(activeStrength ? "continueStrength" : "startStrength"), icon: "dumbbell.fill")
                }.buttonStyle(.plain)
                Button(action: openRun) {
                    TrainingAction(title: display.text(activeRun ? "continueRun" : "running"), icon: "figure.run")
                }.buttonStyle(.plain)
                Button(action: openPrograms) {
                    TrainingAction(title: display.text("programs"), icon: "list.bullet.clipboard")
                }.buttonStyle(.plain)
                TrainingDesign.card {
                    Text(display.text("recent")).font(.headline).accessibilityAddTraits(.isHeader)
                    if activities.isEmpty { Text(display.text("emptyOverview")).foregroundStyle(.secondary) }
                    ForEach(activities.prefix(4)) { ActivityRow(activity: $0, display: display) }
                }
                if let record = activities.compactMap(\.strength).flatMap(\.exercises)
                    .flatMap(\.sets).filter({ $0.metric.isValid && $0.warmup != true && $0.kg > 0 })
                    .max(by: { $0.kg < $1.kg }) {
                    TrainingDesign.card {
                        Text(display.text("records")).font(.headline)
                        LabeledContent(display.text("heaviest"), value: display.weightText(record.kg))
                    }
                }
            }.padding()
        }
        .navigationTitle(display.text("overview"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func weeklyMetrics(_ week: [TrainingActivity]) -> some View {
        VStack(spacing: 8) {
            let known = week.compactMap(\.duration)
            if !known.isEmpty {
                LabeledContent(display.text("duration"), value: display.duration(known.reduce(0, +)))
            }
            let strength = week.compactMap(\.strength)
            if !strength.isEmpty {
                LabeledContent(display.text("volume"), value: display.weightText(strength.reduce(0) { $0 + $1.volume }))
            }
            let runs = week.filter(\.running).compactMap(\.meters)
            if !runs.isEmpty {
                LabeledContent(display.text("distance"), value: display.distanceText(runs.reduce(0, +)))
            }
        }.font(.subheadline)
    }

    private func weekCalendar(start: Date, week: [TrainingActivity]) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack { days(start: start, week: week) }
            VStack(alignment: .leading) { days(start: start, week: week) }
        }
    }

    private func days(start: Date, week: [TrainingActivity]) -> some View {
        ForEach(0..<7) { offset in
            if let day = calendar.date(byAdding: .day, value: offset, to: start) {
                let count = week.filter { calendar.isDate(day, inSameDayAs: $0.date) }.count
                VStack(spacing: 4) {
                    Text(day.formatted(.dateTime.weekday(.narrow).locale(Locale(identifier: display.language.resolved))))
                    Image(systemName: count > 0 ? "checkmark.circle.fill" : "circle").accessibilityHidden(true)
                }.font(.caption)
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: display.language.resolved))))
                    .accessibilityValue(count.formatted(.number.locale(display.locale)))
            }
        }
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

struct TrainingProgress: View {
    @ObservedObject var gym: GymLog
    @ObservedObject var health: TrainingStore
    var display: TrainingPresentation
    var activities: [TrainingActivity]
    var calendar: Calendar
    @State private var range = 30
    @State private var exerciseID = ""

    private var filtered: [TrainingActivity] {
        if range == 0 { return activities }
        let cutoff = calendar.date(byAdding: .day, value: 1 - range, to: calendar.startOfDay(for: .now)) ?? .distantPast
        return activities.filter { $0.date >= cutoff }
    }

    var body: some View {
        let strength = filtered.compactMap(\.strength)
        let runs = filtered.filter { $0.running && $0.meters != nil }
        List {
            Picker(display.text("dateRange"), selection: $range) {
                ForEach([7, 30, 90, 365, 0], id: \.self) { days in
                    Text(display.text("range." + String(days))).tag(days)
                }
            }
            if filtered.isEmpty { Text(display.text("emptyProgress")).foregroundStyle(.secondary) }
            if !strength.isEmpty {
                Section(display.text("volume")) {
                    Chart(strength) { session in
                        BarMark(x: .value(display.text("date"), session.date, unit: .day),
                                y: .value(display.text("volume"), display.weight.display(session.volume)))
                            .foregroundStyle(Color.primary)
                    }.frame(height: 160).accessibilityLabel(display.text("volume"))
                    exerciseChart(strength)
                }
            }
            if !runs.isEmpty {
                Section(display.text("runningDistance")) {
                    Chart(runs) { run in
                        BarMark(x: .value(display.text("date"), run.date, unit: .day),
                                y: .value(display.text("distance"), display.distance.display(run.meters ?? 0)))
                            .foregroundStyle(Color.primary)
                    }.frame(height: 160).accessibilityLabel(display.text("runningDistance"))
                    LabeledContent(display.text("distance"), value: display.distanceText(runs.compactMap(\.meters).reduce(0, +)))
                    if let longest = runs.compactMap(\.meters).max() {
                        LabeledContent(display.text("longestRun"), value: display.distanceText(longest))
                    }
                }
            }
            Section(display.text("history")) {
                ForEach(filtered) { activity in
                    if let session = activity.strength {
                        NavigationLink {
                            StrengthHistoryDetail(gym: gym, display: display, id: session.id)
                        } label: { ActivityRow(activity: activity, display: display) }
                    } else if let run = activity.run {
                        NavigationLink {
                            List {
                                RunMetrics(run: run, date: run.finishDate ?? run.date, display: display)
                                RunRoute(run: run, display: display)
                            }.navigationTitle(display.text("running"))
                        } label: { ActivityRow(activity: activity, display: display) }
                    } else {
                        NavigationLink {
                            ImportedWorkoutDetail(activity: activity, display: display, health: health)
                        } label: { ActivityRow(activity: activity, display: display) }
                    }
                }
            }
        }.navigationTitle(display.text("progress"))
    }

    private func exerciseChart(_ strength: [StrengthSession]) -> some View {
        let choices = Dictionary(grouping: strength.flatMap(\.exercises), by: \.identity)
        let values = strength.compactMap { session -> (date: Date, best: Double)? in
            let sets = session.exercises.filter { $0.identity == exerciseID }.flatMap(\.sets)
                .filter { $0.warmup != true && $0.kg > 0 }.map(\.metric)
            return TrainingMetrics.heaviestWeight(sets).map { (session.date, $0) }
        }.sorted { $0.date < $1.date }
        return Group {
            Picker(display.text("exerciseProgress"), selection: $exerciseID) {
                Text(display.text("selectExercise")).tag("")
                ForEach(choices.keys.sorted(), id: \.self) { key in
                    if let exercise = choices[key]?.first {
                        Text(display.name(exercise, custom: gym.log.customExercises ?? [])).tag(key)
                    }
                }
            }
            if !exerciseID.isEmpty {
                let sets = gym.log.bestSets(for: exerciseID)
                if let best = TrainingMetrics.heaviestWeight(sets) {
                    LabeledContent(display.text("heaviest"), value: display.weightText(best))
                }
                if let estimate = sets.compactMap(TrainingMetrics.estimatedOneRepMax).max() {
                    LabeledContent(display.text("estimatedMax"), value: display.weightText(estimate))
                }
                if values.count > 1 {
                    Chart {
                        ForEach(values.indices, id: \.self) { index in
                            LineMark(x: .value(display.text("date"), values[index].date),
                                     y: .value(display.text("weight"), display.weight.display(values[index].best)))
                            PointMark(x: .value(display.text("date"), values[index].date),
                                      y: .value(display.text("weight"), display.weight.display(values[index].best)))
                        }
                    }.frame(height: 140)
                }
            }
        }
    }
}
