import SwiftUI
import WorkingOutKit

@main
struct WorkingOutWatchApp: App {
    @StateObject private var health: WatchWorkoutHealth
    @StateObject private var workouts: WatchWorkoutStore
    @Environment(\.scenePhase) private var scene

    init() {
        let health = WatchWorkoutHealth()
        _health = StateObject(wrappedValue: health)
        _workouts = StateObject(wrappedValue: WatchWorkoutStore(health: health))
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchTrainingView(workouts: workouts, health: health)
            }
            .onChange(of: scene) { _, value in
                if value == .active { workouts.becameActive() }
            }
        }
    }
}

private struct WatchTrainingView: View {
    @ObservedObject var workouts: WatchWorkoutStore
    @ObservedObject var health: WatchWorkoutHealth
    @State private var replacing = false
    @State private var showingExerciseOptions = false
    @State private var confirmingDiscard = false

    var body: some View {
        Group {
            if let active = workouts.active {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if let index = active.exerciseIndex, let setIndex = active.setIndex {
                            exercise(active, index: index, setIndex: setIndex)
                        } else {
                            Label(text("readyToFinish"), systemImage: "checkmark.circle.fill").font(.headline)
                        }
                        metrics(active)
                        Button(text(active.paused == nil ? "pause" : "resume")) { workouts.togglePause() }
                        Button(text("finish")) { workouts.finish() }
                            .disabled(!active.exercises.contains { $0.exercise.sets.contains(where: \.done) })
                        Button(text("discard"), role: .destructive) { confirmingDiscard = true }
                    }.padding(.horizontal, 4)
                }.navigationTitle(active.title)
            } else {
                List {
                    if workouts.savingHealth { ProgressView(text("saving")) }
                    Section(text("today")) {
                        let today = workouts.feed.plans.filter { $0.scheduledFor != nil && workouts.canOffer($0) }
                        if today.isEmpty { Text(text("noToday")).foregroundStyle(.secondary) }
                        ForEach(today) { plan in planButton(plan) }
                    }
                    Section(text("programs")) {
                        let plans = workouts.feed.plans.filter { $0.scheduledFor == nil }
                        if plans.isEmpty { Text(text("syncPlans")).foregroundStyle(.secondary) }
                        ForEach(plans) { plan in planButton(plan) }
                    }
                }.navigationTitle("WorkingOut")
            }
        }
        .sheet(isPresented: $replacing) {
            NavigationStack {
                List(workouts.feed.replacements) { replacement in
                    Button(replacement.exercise.name) {
                        workouts.change { $0.replaceExercise(with: replacement) }
                        replacing = false
                    }
                }.navigationTitle(text("replace"))
                    .toolbar { Button(text("cancel")) { replacing = false } }
            }
        }
        .confirmationDialog(text("discardQuestion"), isPresented: $confirmingDiscard) {
            Button(text("discard"), role: .destructive) { workouts.discard() }
        }
        .alert(text("storageError"), isPresented: $workouts.error) {
            Button(text("ok"), role: .cancel) {}
        }
    }

    private func planButton(_ plan: WearablePlan) -> some View {
        Button {
            workouts.start(plan)
        } label: {
            Label(plan.title, systemImage: "play.fill").frame(minHeight: 38)
        }.disabled(workouts.savingHealth)
    }

    private func exercise(_ workout: WearableWorkout, index: Int, setIndex: Int) -> some View {
        let current = workout.exercises[index]
        let set = current.exercise.sets[setIndex]
        return VStack(alignment: .leading, spacing: 8) {
            Text(current.exercise.name).font(.title3.bold())
            Text("\(text("set")) \(setIndex + 1) / \(current.exercise.sets.count)").font(.headline)
            if set.warmup == true { Text(text("warmup")).font(.caption) }
            if current.targets.indices.contains(setIndex) {
                let target = current.targets[setIndex]
                let reps = target.warmup != true && current.exercise.progression?.strategy == .doubleProgression
                    ? current.exercise.progression.map { "\($0.minimum)–\($0.maximum)" } ?? target.reps.formatted()
                    : target.reps.formatted()
                Text("\(text("target")) · \(weight(target.kg)) × \(reps)").font(.caption)
            }
            if current.previous.indices.contains(setIndex) {
                let previous = current.previous[setIndex]
                Text("\(text("previous")) · \(weight(previous.kg)) × \(previous.reps)").font(.caption)
            }
            if let recommendation = current.recommendation, set.warmup != true,
               recommendation.reason != .insufficient && recommendation.reason != .manual {
                Text("\(text("suggestion")) · \(weight(recommendation.kg)) × \(recommendation.reps)").font(.caption)
                Text(text("reason." + recommendation.reason.rawValue)).font(.caption2).foregroundStyle(.secondary)
                Button(text("apply")) {
                    workouts.change { $0.adjustCurrent(kg: recommendation.kg, reps: recommendation.reps) }
                }
            }
            Stepper(text("weight"), value: Binding(
                get: { workouts.feed.weight.display(set.kg) },
                set: { value in workouts.change { $0.adjustCurrent(kg: workouts.feed.weight.canonical(value)) } }
            ), in: 0...max(500, workouts.feed.weight.display(set.kg)), step: workouts.feed.weight == .kg ? 0.5 : 1)
            .accessibilityValue(weight(set.kg))
            Text(weight(set.kg)).font(.title3.monospacedDigit())
            Stepper(text("reps"), value: Binding(
                get: { set.reps },
                set: { value in workouts.change { $0.adjustCurrent(reps: value) } }
            ), in: 1...max(100, set.reps))
            .accessibilityValue(set.reps.formatted())
            Text(set.reps.formatted()).font(.title3.monospacedDigit())
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let resting = (workout.restUntil ?? .distantPast) > context.date
                if let restUntil = workout.restUntil, resting {
                    Text(restUntil, style: .timer).font(.headline.monospacedDigit())
                    Button(text("skipRest")) { workouts.change { $0.skipRest() } }
                }
                Button(text("complete")) { workouts.completeSet() }
                    .buttonStyle(.borderedProminent)
                    .disabled(resting || workout.paused != nil)
                    .sensoryFeedback(.success, trigger: resting) { old, new in old && !new }
            }
            if let upcoming = workout.upcoming {
                Text("\(text("next")) · \(upcoming.exercise.name)").font(.footnote)
            }
            Button(text("exerciseOptions")) { showingExerciseOptions = true }
                .confirmationDialog(text("exerciseOptions"), isPresented: $showingExerciseOptions) {
                    Button(text("skipExercise")) { workouts.change { $0.skipExercise() } }
                    if !workouts.feed.replacements.isEmpty {
                        Button(text("replace")) { replacing = true }
                    }
                }
        }
    }

    private func metrics(_ workout: WearableWorkout) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let seconds = Int(workout.duration(at: context.date))
                Text(Duration.seconds(seconds), format: .time(pattern: .minuteSecond))
                    .monospacedDigit().accessibilityLabel(text("duration"))
            }
            if let heart = health.heartRate {
                Label("\(heart.formatted(.number.precision(.fractionLength(0)))) \(text("bpm"))",
                      systemImage: "heart.fill")
            }
            if let energy = health.energy {
                Label("\(energy.formatted(.number.precision(.fractionLength(0)))) kcal", systemImage: "flame.fill")
            }
        }.font(.footnote)
    }

    private func weight(_ kg: Double) -> String {
        let quantity = workouts.feed.weight.display(kg)
        return "\(quantity.formatted(.number.precision(.fractionLength(0...1)))) \(workouts.feed.weight.rawValue)"
    }

    private func text(_ key: String) -> String {
        let selected = workouts.feed.language
        let fallback = Bundle.main.path(forResource: "en", ofType: "lproj").flatMap(Bundle.init(path:))
        let bundle = Bundle.main.path(forResource: selected, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
        return bundle.localizedString(forKey: key,
            value: fallback?.localizedString(forKey: key, value: key, table: "TrainingWatch"), table: "TrainingWatch")
    }
}
