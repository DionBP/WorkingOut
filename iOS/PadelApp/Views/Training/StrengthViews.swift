import SwiftUI
import Charts
import WorkingOutKit

struct StrengthEditor: View {
    @ObservedObject var gym: GymLog
    let display: TrainingPresentation
    let defaultRest: Int
    let save: (StrengthSession) -> Void
    @State private var library = false
    @State private var discard = false

    var body: some View {
        Section {
            if let started = gym.log.started {
                TimelineView(.periodic(from: started, by: 1)) { context in
                    Text(display.duration(gym.log.elapsed(at: context.date) ?? 0))
                        .font(.largeTitle.monospacedDigit().bold())
                }
                Button(display.text(gym.log.paused == nil ? "pause" : "resume")) { gym.pauseOrResume() }
            } else {
                Button(display.text("startStrength"), systemImage: "play.fill") { gym.start() }
            }
            Button(display.text("addExercise"), systemImage: "plus.circle") { library = true }
            if let until = gym.log.restUntil {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let seconds = max(0, ceil(until.timeIntervalSince(context.date)))
                    Label(seconds > 0 ? display.duration(seconds) : display.text("restDone"), systemImage: "timer")
                        .monospacedDigit()
                        .sensoryFeedback(.success, trigger: seconds == 0) { _, ended in ended }
                }
                Button(display.text("skipRest")) { gym.skipRest() }
            }
            if gym.log.started != nil || !gym.log.exercises.isEmpty {
                TextField(display.text("notes"), text: Binding(
                    get: { gym.log.notes ?? "" }, set: { notes in gym.update { $0.notes = notes } }
                ), axis: .vertical)
                Button(display.text("finish")) { if let session = gym.finish() { save(session) } }
                    .disabled(!gym.log.exercises.contains { $0.sets.contains { $0.metric.isValid } })
                Button(display.text("discard"), role: .destructive) { discard = true }
            }
        }
        ForEach(gym.binding(\.exercises)) { $exercise in
            Section {
                let previous = gym.log.previousSets(for: exercise.identity)
                if let last = previous.last {
                    LabeledContent(display.text("previous"), value: "\(display.weightText(last.kg)) × \(last.reps)")
                }
                ForEach($exercise.sets) { $set in
                    VStack(alignment: .leading, spacing: 8) {
                        ViewThatFits(in: .horizontal) {
                            HStack { fields($set); completion(exercise.id, set) }
                            VStack(alignment: .leading) { fields($set); completion(exercise.id, set) }
                        }
                        Toggle(display.text("warmup"), isOn: Binding(
                            get: { set.warmup == true }, set: { set.warmup = $0 }
                        )).font(.caption)
                    }
                }
                .onDelete { exercise.sets.remove(atOffsets: $0) }
                .onMove { exercise.sets.move(fromOffsets: $0, toOffset: $1) }
                Button(display.text("addSet")) {
                    exercise.sets.append(StrengthSet(kg: exercise.sets.last?.kg ?? 0, reps: exercise.sets.last?.reps ?? 10))
                }
            } header: {
                Text(display.name(exercise, custom: gym.log.customExercises ?? []))
            }
            .disabled(gym.log.paused != nil)
        }
        .onDelete { indices in gym.update { $0.exercises.remove(atOffsets: indices) } }
        .onMove { source, destination in gym.update { $0.exercises.move(fromOffsets: source, toOffset: destination) } }
        .sheet(isPresented: $library) {
            ExercisePicker(gym: gym, display: display) { exercise in gym.add(exercise); library = false }
        }
        .confirmationDialog(display.text("discardQuestion"), isPresented: $discard, titleVisibility: .visible) {
            Button(display.text("discard"), role: .destructive) { gym.discard() }
        }
    }

    private func fields(_ set: Binding<StrengthSet>) -> some View {
        HStack {
            TextField(display.weight.rawValue, value: Binding(
                get: { display.weight.display(set.wrappedValue.kg) },
                set: { set.wrappedValue.kg = display.weight.canonical($0) }
            ), format: .number.locale(display.locale))
            .keyboardType(.decimalPad)
            .accessibilityLabel(display.text("weight"))
            Text(display.weight.rawValue).foregroundStyle(.secondary)
            TextField(display.text("reps"), value: set.reps, format: .number.locale(display.locale))
                .keyboardType(.numberPad)
                .accessibilityLabel(display.text("reps"))
            Text(display.text("reps")).foregroundStyle(.secondary)
        }
    }

    private func completion(_ exercise: UUID, _ set: StrengthSet) -> some View {
        Button {
            gym.complete(exerciseID: exercise, setID: set.id, seconds: gym.log.activeRestSeconds ?? defaultRest,
                         message: display.text("restDone"))
        } label: {
            Image(systemName: set.done ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(display.text(set.done ? "undoSet" : "completeSet"))
        .sensoryFeedback(.selection, trigger: set.done)
        .disabled(!set.kg.isFinite || set.kg < 0 || set.reps <= 0)
    }
}

struct ExercisePicker: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var gym: GymLog
    let display: TrainingPresentation
    let select: (StrengthExercise) -> Void
    @State private var search = ""
    @State private var muscle = ""
    @State private var equipment = ""
    @State private var edit: CustomExercise?

    private var results: [ExerciseDefinition] {
        ExerciseCatalog.entries.filter { entry in
            (muscle.isEmpty || entry.primary == muscle || entry.secondary == muscle) &&
                (equipment.isEmpty || entry.equipment == equipment) &&
                (search.isEmpty || display.text(entry.titleKey).localizedCaseInsensitiveContains(search))
        }.sorted { display.text($0.titleKey).localizedStandardCompare(display.text($1.titleKey)) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    filter("muscle", prefix: "muscle.", values: Set(ExerciseCatalog.entries.map(\.primary)), selection: $muscle)
                    filter("equipment", prefix: "equipment.", values: Set(ExerciseCatalog.entries.map(\.equipment)), selection: $equipment)
                }
                Section(display.text("customExercises")) {
                    Button(display.text("newExercise"), systemImage: "plus") { edit = CustomExercise(name: "") }
                    ForEach((gym.log.customExercises ?? []).filter {
                        search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)
                    }) { item in
                        NavigationLink(item.name) {
                            Form {
                                if !item.instructions.isEmpty { Text(item.instructions) }
                                Button(display.text("addExercise")) { select(.init(name: item.name, exerciseID: item.id)) }
                                Button(display.text("edit")) { edit = item }
                            }.navigationTitle(item.name)
                        }
                    }
                }
                Section(display.text("exerciseLibrary")) {
                    ForEach(results) { item in
                        NavigationLink(display.text(item.titleKey)) {
                            Form {
                                LabeledContent(display.text("primaryMuscle"), value: display.text("muscle." + item.primary))
                                if item.secondary != "none" {
                                    LabeledContent(display.text("secondaryMuscle"), value: display.text("muscle." + item.secondary))
                                }
                                LabeledContent(display.text("equipment"), value: display.text("equipment." + item.equipment))
                                Section(display.text("instructions")) { Text(display.text(item.instructionKey)) }
                                Button(display.text("addExercise")) { select(.init(name: display.text(item.titleKey), exerciseID: item.id)) }
                            }.navigationTitle(display.text(item.titleKey))
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: Text(display.text("searchExercises")))
            .navigationTitle(display.text("exerciseLibrary"))
            .toolbar { Button(display.text("close")) { dismiss() } }
            .sheet(item: $edit) { item in
                CustomExerciseEditor(item: item, display: display) { saved in
                    gym.update { log in
                        var items = log.customExercises ?? []
                        items.removeAll { $0.id == saved.id }
                        items.append(saved)
                        log.customExercises = items
                    }
                }
            }
        }
    }

    private func filter(_ key: String, prefix: String, values: Set<String>, selection: Binding<String>) -> some View {
        Picker(display.text(key), selection: selection) {
            Text(display.text("all")).tag("")
            ForEach(values.sorted(), id: \.self) { Text(display.text(prefix + $0)).tag($0) }
        }
    }
}

private struct CustomExerciseEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var item: CustomExercise
    let display: TrainingPresentation
    let save: (CustomExercise) -> Bool

    var body: some View {
        NavigationStack {
            Form {
                TextField(display.text("exerciseName"), text: $item.name)
                TextField(display.text("instructions"), text: $item.instructions, axis: .vertical)
            }
            .navigationTitle(display.text("customExercise"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(display.text("cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(display.text("save")) {
                        item.name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        if save(item) { dismiss() }
                    }
                    .disabled(item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
