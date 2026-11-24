import SwiftUI
import HealthKit
import Charts
import WorkingOutKit

struct RootTabView: View {
    @StateObject private var training = TrainingStore()
    @StateObject private var gym = GymLog()
    @AppStorage("workingout.weeklyGoal") private var weeklyGoal = 3
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("workingout.profileName") private var name = ""
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Image("WorkingOutLogo").resizable().scaledToFit().frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            VStack(alignment: .leading) {
                                Text("WorkingOut").font(.largeTitle.bold())
                                Text("Strength & Running").foregroundStyle(.secondary)
                            }
                        }
                        Button { selectedTab = 1; if training.started == nil { training.kind = .traditionalStrengthTraining } } label: {
                            activityCard("Strength", icon: "dumbbell.fill")
                        }
                        Button { selectedTab = 1; if training.started == nil { training.kind = .running } } label: {
                            activityCard("Running", icon: "figure.run")
                        }
                        let week = training.workouts.filter { Calendar.current.isDate($0.startDate, equalTo: Date(), toGranularity: .weekOfYear) }
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Weekly goal", systemImage: "target").font(.headline)
                            Text("\(week.count) / \(weeklyGoal) workouts").font(.title.bold())
                            ProgressView(value: TrainingMetrics.weeklyProgress(completed: week.count, goal: weeklyGoal), total: 1).tint(.green)
                        }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))
                        Text("Last 30 days").font(.headline)
                        Text("\(training.recent.count) workouts").font(.title2.bold())
                        Text("\(Int(training.recent.reduce(0) { $0 + $1.duration } / 60)) min").foregroundStyle(.secondary)
                        if !training.connected { Button("Connect Apple Health") { Task { await training.connect() } } }
                    }.padding()
                }.navigationTitle("Overview").navigationBarTitleDisplayMode(.inline)
            }.tabItem { Label("Overview", systemImage: "house") }.tag(0)
            NavigationStack {
                Form {
                    Picker("Activity", selection: $training.kind) {
                        Text("Strength").tag(HKWorkoutActivityType.traditionalStrengthTraining)
                        Text("Running").tag(HKWorkoutActivityType.running)
                    }.disabled(training.started != nil)
                    if let start = training.started {
                        Text(start, style: .timer).font(.largeTitle.monospacedDigit())
                        Button("Finish and save") { Task { let strength = training.kind == .traditionalStrengthTraining; await training.finish(); if strength && training.started == nil { gym.finish() } } }.disabled(training.saving)
                        Button("Discard timer", role: .destructive) { training.started = nil }.disabled(training.saving)
                    } else {
                        Button("Start workout") { training.started = Date() }
                    }
                    if training.kind == .traditionalStrengthTraining {
                        GymEditor(gym: gym)
                        if training.started == nil && gym.exercises.flatMap(\.sets).contains(where: \.done) {
                            Button("Save strength log locally") { gym.finish() }
                        }
                    }
                    Text("For Garmin workouts, record on your watch and import through Apple Health instead of recording twice.")
                        .font(.footnote).foregroundStyle(.secondary)
                }.navigationTitle("Training")
            }.tabItem { Label("Training", systemImage: "dumbbell") }.tag(1)
            NavigationStack {
                List {
                    Section("Strength progress") {
                        if !gym.history.isEmpty {
                            Chart(gym.history) { session in
                                BarMark(x: .value("Date", session.date, unit: .day), y: .value("Volume (kg)", session.volume))
                                    .foregroundStyle(Color.green)
                            }.frame(height: 180)
                            ForEach(gym.history.reversed()) { session in
                                NavigationLink {
                                    List {
                                        ForEach(session.exercises) { exercise in
                                            Section(exercise.name) {
                                                ForEach(exercise.sets) { set in Text("\(set.kg, specifier: "%.1f") kg × \(set.reps)") }
                                            }
                                        }
                                    }.navigationTitle("Workout")
                                } label: {
                                    VStack(alignment: .leading) {
                                        Text(session.date, style: .date)
                                        Text("\(session.volume, specifier: "%.0f") kg volume").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        } else { Text("Log your first strength session to see progress.") }
                    }
                    Section("Health workouts") {
                    if training.workouts.isEmpty {
                        Text("No workouts available. Connect Apple Health and check sharing permissions.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(training.workouts, id: \.uuid) { workout in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(workout.workoutActivityType == .running ? "Running" : "Strength").font(.headline)
                            Text(workout.startDate, style: .date)
                            Text("\(Int(workout.duration / 60)) min · \(workout.sourceRevision.source.name)")
                                .font(.caption).foregroundStyle(.secondary)
                            if let distance = workout.totalDistance {
                                Text("\(distance.doubleValue(for: .meterUnit(with: .kilo)), specifier: "%.2f") km")
                            }
                            if workout.workoutActivityType == .running, let distance = workout.totalDistance {
                                let km = distance.doubleValue(for: .meterUnit(with: .kilo))
                                if let pace = TrainingMetrics.runningPaceSeconds(duration: workout.duration, kilometers: km) {
                                    Text(String(format: "%d:%02d /km", pace / 60, pace % 60))
                                }
                            }
                            if let energy = workout.totalEnergyBurned {
                                Text("\(energy.doubleValue(for: .kilocalorie()), specifier: "%.0f") kcal")
                            }
                        }
                    }
                    }
                }.refreshable { await training.refresh() }.navigationTitle("Progress")
            }.tabItem { Label("Progress", systemImage: "chart.bar") }.tag(2)
            NavigationStack {
                Form {
                    TextField("Name", text: $name)
                    Stepper("Weekly goal: \(weeklyGoal) workouts", value: $weeklyGoal, in: 1...14)
                    Section("Apple Health") {
                        Button("Connect / refresh permissions") { Task { await training.connect() } }
                        Button("Refresh workouts") { Task { await training.refresh() } }
                    }
                    Section("Garmin") {
                        Text("Enable Apple Health sharing in Garmin Connect. Sync your watch, open Garmin Connect, then refresh WorkingOut.")
                    }
                }.navigationTitle("Profile")
            }.tabItem { Label("Profile", systemImage: "person.crop.circle") }.tag(3)
        }
        .tint(.primary)
        .task { await training.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await training.refresh() } }
        }
        .alert("WorkingOut", isPresented: Binding(get: { training.error != nil }, set: { if !$0 { training.error = nil } })) {
            Button("OK") { training.error = nil }
        } message: { Text(training.error ?? "") }
    }

    private func activityCard(_ title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon).font(.title)
            Text(title).font(.title2.bold())
            Spacer()
            Image(systemName: "chevron.right")
        }.foregroundStyle(.white).padding(24).background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 20))
    }
}
