import SwiftUI
import WorkingOutKit

struct ProgramList: View {
    @ObservedObject var gym: GymLog
    var display: TrainingPresentation
    var defaultRest: Int
    var start: (StrengthProgram, TrainingDay?) -> Void
    var calendar: Calendar
    var startScheduled: (ProgramOccurrence) -> Void
    var openStrength: () -> Void
    var openRun: () -> Void
    @State private var editing: StrengthProgram?
    @State private var deleting: StrengthProgram?

    static let templates: [(String, [String])] = [
        ("push", ["bench-press", "overhead-press", "lateral-raise", "triceps-pushdown"]),
        ("pull", ["lat-pulldown", "barbell-row", "face-pull", "biceps-curl"]),
        ("legs", ["squat", "romanian-deadlift", "leg-press", "calf-raise"]),
        ("fullBody", ["squat", "bench-press", "barbell-row", "overhead-press"]),
        ("upperBody", ["bench-press", "barbell-row", "overhead-press", "lat-pulldown"]),
        ("lowerBody", ["deadlift", "bulgarian-split-squat", "leg-curl", "calf-raise"])
    ]

    var body: some View {
        TrainingDesign.page {
            if gym.log.started != nil || !gym.log.exercises.isEmpty {
                Button(action: openStrength) { Label(display.text("continueStrength"), systemImage: "play.fill") }
                    .buttonStyle(TrainingCTA())
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    TrainingDesign.section(display.text("savedPrograms"))
                    Spacer(minLength: 8)
                    Button(display.text("newProgram"), systemImage: "plus") {
                        var program = StrengthProgram()
                        program.restSeconds = defaultRest
                        editing = program
                    }
                    .labelStyle(.iconOnly)
                    .font(.title3.weight(.semibold))
                    .frame(minWidth: 44, minHeight: 44)
                }
                if (gym.log.programs ?? []).isEmpty {
                    Text(display.text("emptyPrograms")).font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(gym.log.programs ?? []) { program in
                    programLink(program, saved: true)
                }
            }
            quickActions
            WeeklyPrograms(display: display, calendar: calendar, gym: gym, start: startScheduled)
            VStack(alignment: .leading, spacing: 12) {
                TrainingDesign.section(display.text("templates"))
                ForEach(Self.templates.indices, id: \.self) { index in
                    let (key, ids) = Self.templates[index]
                    programLink(template(key, ids: ids), saved: false)
                }
                if showsMediaCredit {
                    Link(display.text("repdbCredit"), destination: URL(string: "https://repdb.co")!)
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }

        }
        .navigationTitle(display.text("training"))
        .navigationBarTitleDisplayMode(.inline)
        #if DEBUG && targetEnvironment(simulator)
        .onAppear { TrainingScreenshotFixtures.markRendered("training") }
        #endif
        .sheet(item: $editing) { program in
            ProgramEditor(program: program, gym: gym, display: display)
        }
        .confirmationDialog(display.text("deleteQuestion"), isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }
        ), titleVisibility: .visible, presenting: deleting) { program in
            Button(display.text("delete"), role: .destructive) {
                gym.update { $0.programs?.removeAll { $0.id == program.id } }
            }
        }
    }

    private var quickActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { quickActionButtons }
            VStack(alignment: .leading, spacing: 6) { quickActionButtons }
        }
        .font(.subheadline.weight(.semibold))
    }

    @ViewBuilder private var quickActionButtons: some View {
        if gym.log.started == nil && gym.log.exercises.isEmpty {
            Button(display.text("startStrength"), systemImage: "dumbbell.fill", action: openStrength)
                .frame(minHeight: 44)
        }
        Button(display.text(gym.log.activeRun == nil ? "running" : "continueRun"),
               systemImage: "figure.run", action: openRun)
            .frame(minHeight: 44)
    }

    private func template(_ key: String, ids: [String]) -> StrengthProgram {
        var program = StrengthProgram()
        program.name = display.text("program." + key)
        program.exercises = ids.map { StrengthExercise(name: display.text("exercise." + $0), exerciseID: $0) }
        program.restSeconds = defaultRest
        return program
    }

    private var showsMediaCredit: Bool {
        let ids = Self.templates.flatMap { $0.1 } + (gym.log.programs ?? []).flatMap { program in
            (program.exercises + (program.days ?? []).flatMap(\.exercises)).compactMap(\.exerciseID)
        }
        return ids.contains { ExerciseSnapshot.bundled.media?.illustration(for: $0) != nil }
    }

    private func programLink(_ program: StrengthProgram, saved: Bool) -> some View {
        let preview = program.days?.first?.exercises ?? program.exercises
        return NavigationLink {
            TrainingDesign.page {
                if !program.notes.isEmpty { Text(program.notes) }
                if let days = program.days, !days.isEmpty {
                    TrainingDesign.section(display.text("trainingDays"))
                    ForEach(days.sorted { $0.weekday < $1.weekday }) { day in
                        NavigationLink {
                            TrainingDesign.page {
                                workout(program, day: day, exercises: day.exercises)
                            }.navigationTitle(day.name)
                        } label: {
                            programRow(day.name, exercises: day.exercises)
                        }.buttonStyle(.plain)
                    }
                } else {
                    workout(program, day: nil, exercises: program.exercises)
                }
                Button(display.text("duplicate"), systemImage: "plus.square.on.square") {
                    var copy = program
                    copy.id = UUID()
                    copy.days = copy.days?.map { source in
                        var day = source
                        day.id = UUID()
                        return day
                    }
                    editing = copy
                }.frame(minHeight: 44)
                if saved {
                    Button(display.text("edit"), systemImage: "pencil") { editing = program }.frame(minHeight: 44)
                    Button(display.text("delete"), systemImage: "trash", role: .destructive) { deleting = program }.frame(minHeight: 44)
                }
            }
            .navigationTitle(program.name)
        } label: {
            programRow(program.name, exercises: preview)
        }.buttonStyle(.plain)
    }

    private func programRow(_ title: String, exercises: [StrengthExercise]) -> some View {
        HStack(spacing: 12) {
            ExerciseThumbnail(id: ExerciseThumbnail.featured(in: exercises), display: display)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(exercises.prefix(2).map { display.name($0, custom: gym.log.customExercises ?? []) }.joined(separator: " · "))
                    .foregroundStyle(.secondary).font(.subheadline).lineLimit(2)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.caption).accessibilityHidden(true)
        }
        .padding(10)
        .background(TrainingDesign.surface, in: RoundedRectangle(cornerRadius: 14))
        .contentShape(Rectangle())
    }

    private func workout(_ program: StrengthProgram, day: TrainingDay?, exercises: [StrengthExercise]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(display.text("startProgram"), systemImage: "play.fill") { start(program, day) }
                .buttonStyle(TrainingCTA())
                .disabled(gym.log.started != nil || !gym.log.exercises.isEmpty)
            ForEach(exercises) { exercise in
                exercisePreview(exercise)
                if exercise.id != exercises.last?.id { Divider() }
            }
            if exercises.contains(where: { ExerciseSnapshot.bundled.media?.illustration(for: $0.identity) != nil }) {
                Link(display.text("repdbCredit"), destination: URL(string: "https://repdb.co")!)
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func exercisePreview(_ exercise: StrengthExercise) -> some View {
        let prepared = gym.prepare(exercise)
        let working = prepared.sets.filter { $0.warmup != true }
        let reps: String
        if let progression = exercise.progression, progression.strategy == .doubleProgression {
            reps = "\(progression.minimum)–\(progression.maximum)"
        } else {
            reps = working.map { String($0.reps) }.joined(separator: "/")
        }
        return HStack(alignment: .top, spacing: 12) {
            ExerciseThumbnail(id: exercise.exerciseID, display: display)
            VStack(alignment: .leading, spacing: 4) {
                Text(display.name(exercise, custom: gym.log.customExercises ?? [])).font(.headline)
                Text("\(working.count) \(display.text("workSets")) · \(reps) \(display.text("reps"))")
                if let last = gym.log.previousSets(for: exercise.identity).last(where: { $0.warmup != true }) {
                    Text("\(display.text("previous")) · \(display.weightText(last.kg)) × \(last.reps)")
                }
                if let suggestion = gym.recommendation(for: prepared),
                   suggestion.reason != .insufficient, suggestion.reason != .manual {
                    Text("\(display.text("recommended")) · \(display.weightText(suggestion.kg)) × \(suggestion.reps)")
                } else if let target = working.first {
                    Text("\(display.text("targetWeight")) · \(display.weightText(target.kg))")
                }
            }.font(.subheadline).foregroundStyle(.primary)
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }

}

struct ProgramEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var program: StrengthProgram
    @ObservedObject var gym: GymLog
    let display: TrainingPresentation

    var body: some View {
        NavigationStack {
            Form {
                TextField(display.text("programName"), text: $program.name)
                TextField(display.text("notes"), text: $program.notes, axis: .vertical)
                Stepper("\(display.text("restTimer")) · \(display.duration(Double(program.restSeconds)))",
                        value: $program.restSeconds, in: 15...600, step: 15)
                if program.days?.isEmpty != false {
                    ExerciseTargets(exercises: $program.exercises, gym: gym, display: display)
                }
                Section(display.text("trainingDays")) {
                    ForEach(days) { $day in
                        NavigationLink(day.name.isEmpty ? display.text("trainingDay") : day.name) {
                            TrainingDayEditor(day: $day, gym: gym, display: display)
                        }
                        .swipeActions {
                            Button(display.text("duplicateDay")) {
                                var copy = day
                                copy.id = UUID()
                                days.wrappedValue.append(copy)
                            }
                        }
                    }
                    .onDelete { days.wrappedValue.remove(atOffsets: $0) }
                    Button(display.text("addDay"), systemImage: "plus.circle") { addDay() }
                }
            }
            .navigationTitle(display.text("programs"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(display.text("cancel")) { dismiss() } }
                ToolbarItemGroup(placement: .primaryAction) {
                    EditButton()
                    Button(display.text("save")) { save() }.disabled(!program.isValid)
                }
            }

        }
    }

    private var days: Binding<[TrainingDay]> {
        Binding(get: { program.days ?? [] }, set: { program.days = $0 })
    }

    private func addDay() {
        var day = TrainingDay()
        day.name = display.text("trainingDay")
        day.restSeconds = program.restSeconds
        if days.wrappedValue.isEmpty && !program.exercises.isEmpty {
            day.exercises = program.exercises
            day.name = display.text("legacyProgramDay")
        }
        days.wrappedValue.append(day)
    }

    private func save() {
        program.name = program.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if gym.update({ log in
            var programs = log.programs ?? []
            if let index = programs.firstIndex(where: { $0.id == program.id }) {
                programs[index] = program
            } else {
                programs.append(program)
            }
            log.programs = programs
        }) { dismiss() }
    }
}
