import SwiftUI
import WorkingOutKit

struct TrainingDayEditor: View {
    @Binding var day: TrainingDay
    @ObservedObject var gym: GymLog
    let display: TrainingPresentation

    var body: some View {
        Form {
            TextField(display.text("dayName"), text: $day.name)
            Picker(display.text("weekday"), selection: $day.weekday) {
                ForEach(1...7, id: \.self) { day in
                    Text(display.text("weekday." + String(day))).tag(day)
                }
            }
            Stepper("\(display.text("restTimer")) · \(display.duration(Double(day.restSeconds)))",
                    value: $day.restSeconds, in: 15...600, step: 15)
            ExerciseTargets(exercises: $day.exercises, gym: gym, display: display)
        }
        .navigationTitle(display.text("trainingDay"))
        .toolbar { EditButton().environment(\.locale, Locale(identifier: display.language.resolved)) }
    }
}

struct ExerciseTargets: View {
    @Binding var exercises: [StrengthExercise]
    @ObservedObject var gym: GymLog
    let display: TrainingPresentation
    @State private var pickExercise = false

    private func targetSummary(_ exercise: StrengthExercise) -> String {
        let working = exercise.sets.filter { $0.warmup != true }
        let reps = exercise.progression.map { "\($0.minimum)–\($0.maximum)" }
            ?? working.map { String($0.reps) }.joined(separator: "/")
        return "\(working.count) \(display.text("workSets")) · \(reps) \(display.text("reps"))"
    }

    var body: some View {
        Section(display.text("exerciseLibrary")) {
            ForEach($exercises) { $exercise in
                NavigationLink {
                    ExerciseTargetEditor(exercise: $exercise, display: display,
                                         title: display.name(exercise, custom: gym.log.customExercises ?? []))
                } label: {
                    HStack(spacing: 12) {
                        ExerciseThumbnail(id: exercise.exerciseID, display: display)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(display.name(exercise, custom: gym.log.customExercises ?? []))
                                .font(.headline)
                            Text(targetSummary(exercise))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(10)
                    .background(TrainingDesign.surface, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .onMove { exercises.move(fromOffsets: $0, toOffset: $1) }
            .onDelete { exercises.remove(atOffsets: $0) }
            Button(display.text("addExercise"), systemImage: "plus.circle") { pickExercise = true }
        }
        .sheet(isPresented: $pickExercise) {
            ExercisePicker(gym: gym, display: display) { choice in
                var exercise = choice
                var target = ProgressionTarget()
                let equipment = ExerciseCatalog.byID[exercise.identity]?.equipment
                if equipment == "bodyweight" { target.loadKind = .bodyweight }
                if exercise.identity == "assisted-pull-up" { target.loadKind = .assisted }
                target.useLastLoad = true
                exercise.progression = target
                exercises.append(exercise)
                pickExercise = false
            }
        }
    }
}

private struct ExerciseTargetEditor: View {
    @Binding var exercise: StrengthExercise
    let display: TrainingPresentation
    let title: String

    private var target: Binding<ProgressionTarget> {
        Binding(get: {
            if let saved = exercise.progression { return saved }
            var legacy = ProgressionTarget()
            legacy.strategy = .manual
            return legacy
        }, set: { exercise.progression = $0 })
    }

    var body: some View {
        Form {
            Section(display.text("exerciseName")) {
                TextField(display.text("exerciseName"), text: Binding(
                    get: { exercise.customName ?? title },
                    set: { value in
                        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                        exercise.customName = trimmed.isEmpty || trimmed == title ? nil : trimmed
                    }
                ))
                .textInputAutocapitalization(.words)
            }
            Section(display.text("progressionStrategy")) {
                Picker(display.text("progressionStrategy"), selection: target.strategy) {
                    ForEach(ProgressionStrategy.allCases) { strategy in
                        Text(display.text("strategy." + strategy.rawValue)).tag(strategy)
                    }
                }
                if target.wrappedValue.strategy == .doubleProgression {
                    Toggle(display.text("useLastLoad"), isOn: Binding(
                        get: { target.wrappedValue.useLastLoad == true },
                        set: { target.wrappedValue.useLastLoad = $0 }
                    ))
                    Picker(display.text("loadType"), selection: target.loadKind) {
                        ForEach(LoadKind.allCases) { kind in Text(display.text("load." + kind.rawValue)).tag(kind) }
                    }
                    Stepper("\(display.text("minimumReps")) · \(target.wrappedValue.minimum)",
                            value: target.minimum, in: 1...max(1, target.wrappedValue.maximum))
                    Stepper("\(display.text("maximumReps")) · \(target.wrappedValue.maximum)",
                            value: target.maximum, in: min(100, target.wrappedValue.minimum)...100)
                    TextField(display.text("weightIncrement"), value: Binding<Double?>(
                        get: { target.wrappedValue.incrementKg.map(display.weight.display) },
                        set: { value in target.wrappedValue.incrementKg = value.map(display.weight.canonical) }
                    ), format: .number.locale(display.locale))
                    .keyboardType(.decimalPad)
                    LabeledContent(display.text("equipmentIncrement"),
                                   value: display.weightText(ProgressionTarget.defaultIncrement(equipment: ExerciseCatalog.byID[exercise.identity]?.equipment)))
                }
                Stepper("\(display.text("restTimer")) · \(display.duration(Double(exercise.restSeconds ?? 90)))",
                        value: Binding(get: { exercise.restSeconds ?? 90 }, set: { exercise.restSeconds = $0 }),
                        in: 15...600, step: 15)
            }
            Section {
                ForEach($exercise.sets) { $set in
                    TextField(display.text("targetReps"), value: $set.reps, format: .number.locale(display.locale))
                        .keyboardType(.numberPad)
                    TextField("\(display.text("targetWeight")) (\(display.weight.rawValue))", value: Binding(
                        get: { display.weight.display(set.kg) }, set: { set.kg = display.weight.canonical($0) }
                    ), format: .number.locale(display.locale))
                    .keyboardType(.decimalPad)
                    Toggle(display.text("warmup"), isOn: Binding(get: { set.warmup == true }, set: { set.warmup = $0 }))
                }
                .onDelete { exercise.sets.remove(atOffsets: $0) }
                .onMove { exercise.sets.move(fromOffsets: $0, toOffset: $1) }
                Button(display.text("addSet")) { exercise.sets.append(StrengthSet(reps: target.wrappedValue.minimum)) }
            }
        }
        .navigationTitle(title)
        .toolbar { EditButton().environment(\.locale, Locale(identifier: display.language.resolved)) }
    }
}
