import SwiftUI
import WorkingOutKit

struct ProgramList: View {
    @ObservedObject var gym: GymLog
    var display: TrainingPresentation
    var defaultRest: Int
    var start: (StrengthProgram, TrainingDay?) -> Void
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
        List {
            Section(display.text("savedPrograms")) {
                Button(display.text("newProgram"), systemImage: "plus") {
                    var program = StrengthProgram()
                    program.restSeconds = defaultRest
                    editing = program
                }
                ForEach(gym.log.programs ?? []) { program in
                    programLink(program)
                        .swipeActions {
                            Button(role: .destructive) { deleting = program } label: { Text(display.text("delete")) }
                            Button { editing = program } label: { Text(display.text("edit")) }
                        }
                }
            }
            Section(display.text("templates")) {
                ForEach(Self.templates.indices, id: \.self) { index in
                    let (key, ids) = Self.templates[index]
                    programLink(template(key, ids: ids))
                }
            }
        }
        .navigationTitle(display.text("programs"))
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

    private func template(_ key: String, ids: [String]) -> StrengthProgram {
        var program = StrengthProgram()
        program.name = display.text("program." + key)
        program.exercises = ids.map { StrengthExercise(name: display.text("exercise." + $0), exerciseID: $0) }
        program.restSeconds = defaultRest
        return program
    }

    private func programLink(_ program: StrengthProgram) -> some View {
        NavigationLink(program.name) {
            List {
                if let days = program.days, !days.isEmpty {
                    Section(display.text("trainingDays")) {
                        ForEach(days.sorted { $0.weekday < $1.weekday }) { day in
                            NavigationLink(day.name) {
                                List {
                                    Button(display.text("startProgram"), systemImage: "play.fill") { start(program, day) }
                                        .disabled(gym.log.started != nil || !gym.log.exercises.isEmpty)
                                    ForEach(day.exercises) { exercise in
                                        Text(display.name(exercise, custom: gym.log.customExercises ?? []))
                                    }
                                }.navigationTitle(day.name)
                            }
                        }
                    }
                } else {
                    Button(display.text("startProgram"), systemImage: "play.fill") { start(program, nil) }
                        .disabled(gym.log.started != nil || !gym.log.exercises.isEmpty)
                }
                if !program.notes.isEmpty { Text(program.notes) }
                if program.days?.isEmpty != false {
                    ForEach(program.exercises) { exercise in
                        Text(display.name(exercise, custom: gym.log.customExercises ?? []))
                    }
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
                }
                if gym.log.programs?.contains(where: { $0.id == program.id }) == true {
                    Button(display.text("edit"), systemImage: "pencil") { editing = program }
                }
            }
            .navigationTitle(program.name)
        }
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
