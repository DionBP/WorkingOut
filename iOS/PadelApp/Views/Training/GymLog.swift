import SwiftUI
import Combine

struct GymSet: Codable, Identifiable {
    var id = UUID()
    var kg: Double = 0
    var reps: Int = 10
    var done = false
}
struct GymExercise: Codable, Identifiable {
    var id = UUID()
    var name: String
    var sets: [GymSet] = [GymSet(), GymSet(), GymSet()]
}
struct GymSession: Codable, Identifiable {
    var id = UUID()
    var date = Date()
    var exercises: [GymExercise]
    var volume: Double { exercises.flatMap(\.sets).filter(\.done).reduce(0) { $0 + $1.kg * Double($1.reps) } }
}
struct GymRoutine: Identifiable {
    var name: String
    var exercises: [String]
    var id: String { name }
}

@MainActor
final class GymLog: ObservableObject {
    @Published var exercises: [GymExercise] = [] { didSet { persist() } }
    @Published var history: [GymSession] = [] { didSet { persist() } }
    @Published var restUntil: Date?
    @Published var restSeconds = 90
    private let url = URL.documentsDirectory.appendingPathComponent("workingout-gym-v1.json")
    private struct Snapshot: Codable { var exercises: [GymExercise]; var history: [GymSession] }
    static let library = ["Bench Press", "Incline Dumbbell Press", "Push-up", "Overhead Press", "Lateral Raise", "Triceps Pushdown", "Pull-up", "Lat Pulldown", "Barbell Row", "Seated Cable Row", "Biceps Curl", "Hammer Curl", "Face Pull", "Squat", "Deadlift", "Romanian Deadlift", "Leg Press", "Leg Extension", "Leg Curl", "Calf Raise", "Lunge", "Hip Thrust", "Plank", "Cable Crunch", "Dumbbell Fly", "Chest Press", "Goblet Squat", "Bulgarian Split Squat", "Preacher Curl", "Back Extension"]
    static let routines = [
        GymRoutine(name: "Push", exercises: ["Bench Press", "Overhead Press", "Lateral Raise", "Triceps Pushdown"]),
        GymRoutine(name: "Pull", exercises: ["Lat Pulldown", "Barbell Row", "Face Pull", "Biceps Curl"]),
        GymRoutine(name: "Legs", exercises: ["Squat", "Romanian Deadlift", "Leg Press", "Calf Raise"]),
        GymRoutine(name: "Full Body", exercises: ["Squat", "Bench Press", "Barbell Row", "Overhead Press"])
    ]
    init() {
        if let data = try? Data(contentsOf: url), let saved = try? JSONDecoder().decode(Snapshot.self, from: data) {
            exercises = saved.exercises; history = saved.history
        }
    }
    private func persist() {
        if let data = try? JSONEncoder().encode(Snapshot(exercises: exercises, history: history)) {
            try? data.write(to: url, options: [.atomic, .completeFileProtection])
        }
    }
    func add(_ name: String) {
        let prior = history.reversed().flatMap(\.exercises).first { $0.name == name }
        let sets = prior?.sets.filter(\.done).map { GymSet(kg: $0.kg, reps: $0.reps) } ?? []
        exercises.append(GymExercise(name: name, sets: sets.isEmpty ? [GymSet(), GymSet(), GymSet()] : sets))
    }
    func finish() {
        let completed = exercises.map { exercise in
            var copy = exercise; copy.sets = copy.sets.filter(\.done); return copy
        }.filter { !$0.sets.isEmpty }
        if !completed.isEmpty { history.append(GymSession(exercises: completed)) }
        exercises = []; restUntil = nil
    }
    func record(for name: String) -> Double {
        history.flatMap(\.exercises).filter { $0.name == name }.flatMap(\.sets).filter(\.done).map(\.kg).max() ?? 0
    }
}

struct GymEditor: View {
    @ObservedObject var gym: GymLog
    @State private var search = ""
    @State private var custom = ""
    @State private var library = false
    var body: some View {
        Section("Strength log") {
            if gym.exercises.isEmpty {
                ForEach(GymLog.routines) { routine in
                    Button(routine.name) { routine.exercises.forEach { gym.add($0) } }
                }
            }
            Button("Add exercise", systemImage: "plus.circle") { library = true }
            Picker("Rest timer", selection: $gym.restSeconds) {
                ForEach([30, 60, 90, 120, 180], id: \.self) { Text("\($0) sec").tag($0) }
            }
            if let until = gym.restUntil {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let seconds = max(0, Int(ceil(until.timeIntervalSince(context.date))))
                    HStack { Label(seconds > 0 ? "Rest: \(seconds)s" : "Ready for next set", systemImage: "timer"); Spacer(); Button("Skip") { gym.restUntil = nil }.buttonStyle(.borderless) }
                }
            }
        }
        ForEach($gym.exercises) { $exercise in
            Section {
                HStack { Text("Set").frame(width: 28); Text("kg").frame(maxWidth: .infinity); Text("Reps").frame(maxWidth: .infinity); Text("Done") }.font(.caption).foregroundStyle(.secondary)
                ForEach($exercise.sets) { $set in
                    HStack {
                        Text("\((exercise.sets.firstIndex { $0.id == set.id } ?? 0) + 1)").frame(width: 28)
                        TextField("kg", value: $set.kg, format: .number).keyboardType(.decimalPad).frame(maxWidth: .infinity)
                        TextField("reps", value: $set.reps, format: .number).keyboardType(.numberPad).frame(maxWidth: .infinity)
                        Button {
                            guard set.kg >= 0, set.reps > 0 else { return }
                            set.done.toggle()
                            if set.done { gym.restUntil = Date().addingTimeInterval(Double(gym.restSeconds)) }
                        } label: { Image(systemName: set.done ? "checkmark.circle.fill" : "circle").font(.title2).foregroundStyle(set.done ? Color.green : Color.secondary) }.buttonStyle(.borderless)
                    }
                }.onDelete { exercise.sets.remove(atOffsets: $0) }
                Button("Add set") { exercise.sets.append(GymSet(kg: exercise.sets.last?.kg ?? 0, reps: exercise.sets.last?.reps ?? 10)) }
            } header: {
                HStack { Text(exercise.name); Spacer(); if gym.record(for: exercise.name) > 0 { Text("Best \(gym.record(for: exercise.name), specifier: "%.1f") kg") } }
            }
        }.onDelete { gym.exercises.remove(atOffsets: $0) }
        .sheet(isPresented: $library) {
            NavigationStack {
                List {
                    Section("Custom exercise") {
                        TextField("Exercise name", text: $custom)
                        Button("Add custom exercise") {
                            let name = custom.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !name.isEmpty { gym.add(name); custom = ""; library = false }
                        }
                    }
                    ForEach(GymLog.library.filter { search.isEmpty || $0.localizedCaseInsensitiveContains(search) }, id: \.self) { name in
                        Button(name) { gym.add(name); library = false }
                    }
                }.searchable(text: $search).navigationTitle("Exercises").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { library = false } } }
            }
        }
    }
}
