import SwiftUI
import WorkingOutKit

struct StrengthHistoryDetail: View {
    @ObservedObject var gym: GymLog
    var display: TrainingPresentation
    var id: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var program: StrengthProgram?
    @State private var deleting = false
    @State private var editing = false

    var body: some View {
        List {
            if let session = gym.log.history.first(where: { $0.id == id }) {
                Section {
                    if let duration = session.duration {
                        LabeledContent(display.text("duration"), value: display.duration(duration))
                    }
                    LabeledContent(display.text("volume"), value: display.weightText(session.volume))
                    if let notes = session.notes, !notes.isEmpty { Text(notes) }
                    Button(display.text("edit")) { editing = true }
                    Button(display.text("saveAsProgram")) {
                        var copy = StrengthProgram()
                        copy.exercises = session.exercises.map { exercise in
                            var target = exercise
                            target.sets = target.sets.map { set in
                                StrengthSet(kg: set.kg, reps: set.reps, warmup: set.warmup)
                            }
                            return target
                        }
                        program = copy
                    }
                    Button(display.text("delete"), role: .destructive) { deleting = true }
                }
                ForEach(session.exercises) { exercise in
                    Section(display.name(exercise, custom: gym.log.customExercises ?? [])) {
                        ForEach(exercise.sets) { set in
                            VStack(alignment: .leading) {
                                Text("\(display.weightText(set.kg)) × \(set.reps.formatted(.number.locale(display.locale)))")
                                if set.warmup == true { Text(display.text("warmup")).font(.caption) }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(display.text("workout"))
        .sheet(item: $program) { value in ProgramEditor(program: value, gym: gym, display: display) }
        .sheet(isPresented: $editing) {
            if let session = gym.log.history.first(where: { $0.id == id }) {
                CompletedWorkoutEditor(session: session, gym: gym, display: display)
            }
        }
        .confirmationDialog(display.text("deleteWorkoutQuestion"), isPresented: $deleting, titleVisibility: .visible) {
            Button(display.text("delete"), role: .destructive) {
                if gym.update({ $0.deleteSession(id: id) }) { dismiss() }
            }
        }
    }
}

private struct CompletedWorkoutEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var session: StrengthSession
    @ObservedObject var gym: GymLog
    let display: TrainingPresentation

    var body: some View {
        NavigationStack {
            Form {
                TextField(display.text("notes"), text: Binding(
                    get: { session.notes ?? "" }, set: { session.notes = $0 }
                ), axis: .vertical)
                ForEach($session.exercises) { $exercise in
                    Section(display.name(exercise, custom: gym.log.customExercises ?? [])) {
                        ForEach($exercise.sets) { $set in
                            TextField(display.text("weight"), value: Binding(
                                get: { display.weight.display(set.kg) }, set: { set.kg = display.weight.canonical($0) }
                            ), format: .number.locale(display.locale)).keyboardType(.decimalPad)
                            TextField(display.text("reps"), value: $set.reps, format: .number.locale(display.locale))
                                .keyboardType(.numberPad)
                            Toggle(display.text("warmup"), isOn: Binding(
                                get: { set.warmup == true }, set: { set.warmup = $0 }
                            ))
                        }
                    }
                }
            }
            .navigationTitle(display.text("workout"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(display.text("cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(display.text("save")) {
                        if gym.update({ log in
                            if let index = log.history.firstIndex(where: { $0.id == session.id }) {
                                log.history[index] = session
                            }
                        }) { dismiss() }
                    }
                    .disabled(!session.exercises.flatMap(\.sets).allSatisfy(\.metric.isValid))
                }
            }
        }
    }
}
