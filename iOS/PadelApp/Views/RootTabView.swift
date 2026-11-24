import SwiftUI
import HealthKit
import UserNotifications
import WorkingOutKit

struct RootTabView: View {
    @StateObject private var health = TrainingStore()
    @StateObject private var tracker = RunLocationTracker()
    @StateObject private var gym = GymLog()
    @AppStorage("workingout.weeklyGoal") private var weeklyGoal = 3
    @AppStorage("workingout.profileName") private var name = ""
    @AppStorage("workingout.language") private var language = WorkingOutLanguage.system
    @AppStorage("workingout.weightUnit") private var weight = WeightUnit.kg
    @AppStorage("workingout.distanceUnit") private var distance = DistanceUnit.km
    @AppStorage("workingout.restSeconds") private var rest = 90
    @AppStorage("workingout.firstWeekday") private var firstWeekday = 0
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var regionalLocale
    @State private var selectedTab = 0
    @State private var trainingPath: [TrainingRoute] = []
    enum TrainingRoute: Hashable { case strength, run, programs }

    private var display: TrainingPresentation {
        TrainingPresentation(language: language, weight: weight, distance: distance, locale: regionalLocale)
    }

    private var calendar: Calendar {
        var result = Calendar.current
        if (1...7).contains(firstWeekday) { result.firstWeekday = firstWeekday }
        return result
    }

    private var activities: [TrainingActivity] {
        let runs = gym.log.runs ?? []
        return TrainingActivity.list(local: gym.log.history, runs: runs, external: health.unlinkedWorkouts(gym.log))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TrainingOverview(display: display, calendar: calendar, activities: activities, goal: weeklyGoal,
                                 activeStrength: gym.log.started != nil || !gym.log.exercises.isEmpty,
                                 activeRun: gym.log.activeRun != nil, openStrength: { open(.strength) },
                                 openRun: { open(.run) }, openPrograms: { open(.programs) })
            }.tabItem { Label(display.text("overview"), systemImage: "house") }.tag(0)
            NavigationStack(path: $trainingPath) {
                ScrollView {
                    VStack(spacing: 14) {
                        action(gym.log.started != nil ? "continueStrength" : "strength", icon: "dumbbell.fill", route: .strength)
                        action(gym.log.activeRun != nil ? "continueRun" : "running", icon: "figure.run", route: .run)
                        action("programs", icon: "list.bullet.clipboard", route: .programs)
                    }.padding()
                }
                .navigationTitle(display.text("training"))
                .navigationDestination(for: TrainingRoute.self) { route in
                    switch route {
                    case .strength:
                        List {
                            StrengthEditor(gym: gym, display: display, defaultRest: rest, save: mirror)
                        }
                        .navigationTitle(display.text("strength"))
                        .toolbar { EditButton().environment(\.locale, Locale(identifier: language.resolved)) }
                    case .run:
                        RunEditor(gym: gym, tracker: tracker, health: health, display: display, mirror: mirrorRun)
                    case .programs:
                        ProgramList(gym: gym, display: display, defaultRest: rest) { program in
                            gym.start(program: program)
                            if gym.log.started != nil { trainingPath = [.strength] }
                        }
                    }
                }
            }.tabItem { Label(display.text("training"), systemImage: "dumbbell") }.tag(1)
            NavigationStack {
                TrainingProgress(gym: gym, health: health, display: display, activities: activities, calendar: calendar)
                    .refreshable { await health.refresh(reportErrors: true) }
            }.tabItem { Label(display.text("progress"), systemImage: "chart.bar") }.tag(2)
            NavigationStack { profile }
                .tabItem { Label(display.text("profile"), systemImage: "person.crop.circle") }.tag(3)
        }
        .tint(.primary)
        .task { await health.refresh() }
        .onChange(of: shouldTrackRun, initial: true) { _, active in
            if active { startTracking() }
            else { tracker.stop() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await health.refresh() } }
        }
        .alert(display.text("health"), isPresented: Binding(
            get: { health.issue != nil }, set: { if !$0 { health.issue = nil } }
        )) {
            Button(display.text("ok")) { health.issue = nil }
        } message: {
            if let issue = health.issue { Text(display.text(issue)) }
        }
        .alert(display.text("storageTitle"), isPresented: $gym.storageError) {
            Button(display.text("ok"), role: .cancel) {}
        } message: { Text(display.text(gym.inaccessible ? "storageRead" : "storageWrite")) }
    }

    private var profile: some View {
        List {
            Section(display.text("profile")) {
                TextField(display.text("name"), text: $name)
                    .textContentType(.name)
                Stepper("\(display.text("weeklyGoal")) · \(weeklyGoal.formatted(.number.locale(regionalLocale)))",
                        value: $weeklyGoal, in: 1...14)
            }
            Section(display.text("preferences")) {
                Picker(display.text("language"), selection: $language) {
                    ForEach(WorkingOutLanguage.allCases) { option in Text(display.text("language." + option.rawValue)).tag(option) }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("workingout.language")
                Picker(display.text("weight"), selection: $weight) {
                    ForEach(WeightUnit.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker(display.text("distance"), selection: $distance) {
                    ForEach(DistanceUnit.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker(display.text("appearance"), selection: $appearance) {
                    ForEach(AppAppearance.allCases) { Text(display.text("appearance." + $0.rawValue)).tag($0) }
                }
                Picker(display.text("firstDay"), selection: $firstWeekday) {
                    Text(display.text("language.system")).tag(0)
                    ForEach(1...7, id: \.self) { day in
                        Text(display.text("weekday." + String(day))).tag(day)
                    }
                }
                Stepper("\(display.text("restTimer")) · \(display.duration(Double(rest)))",
                        value: $rest, in: 15...600, step: 15)
                Button(display.text("restNotifications")) {
                    Task { _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) }
                }
            }
            Section(display.text("health")) {
                Text(display.text("healthGuide"))
                Button(display.text("healthConnect")) { Task { await health.connect() } }.disabled(!health.available)
                Button(display.text("healthRefresh")) { Task { await health.refresh(reportErrors: true) } }.disabled(!health.available)
                if health.canWrite { Text(display.text("healthWriteEnabled")).foregroundStyle(.secondary) }
            }
            Section(display.text("garmin")) { Text(display.text("garminGuide")) }
            Section(display.text("privacy")) {
                Text(display.text("privacyGuide"))
                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                   let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                    LabeledContent(display.text("version"), value: "\(version) (\(build))")
                }
            }
        }.navigationTitle(display.text("profile"))
    }

    private var shouldTrackRun: Bool {
        gym.log.activeRun != nil && gym.log.activeRun?.paused == nil && tracker.authorized
    }

    private func startTracking() {
        tracker.begin { [weak gym] location, delta, newSegment in
            guard let gym, let run = gym.log.activeRun, run.paused == nil else { return false }
            return gym.update { log in
                log.activeRun?.points.append(RunPoint(
                    latitude: location.coordinate.latitude, longitude: location.coordinate.longitude,
                    elapsed: run.elapsed(at: location.timestamp), meters: (run.points.last?.meters ?? 0) + delta,
                    newSegment: newSegment
                ))
            }
        }
    }

    private func mirrorRun(_ run: RunRecord) {
        Task {
            guard let healthID = await health.mirror(run) else { return }
            gym.update { log in
                if let index = log.runs?.firstIndex(where: { $0.id == run.id }) {
                    log.runs?[index].healthID = healthID
                }
            }
        }
    }

    private func action(_ key: String, icon: String, route: TrainingRoute) -> some View {
        Button { trainingPath.append(route) } label: {
            TrainingAction(title: display.text(key), icon: icon)
        }.buttonStyle(.plain)
    }

    private func open(_ route: TrainingRoute) {
        trainingPath = [route]
        selectedTab = 1
    }

    private func mirror(_ session: StrengthSession) {
        Task {
            guard let healthID = await health.mirror(session) else { return }
            gym.update { log in
                if let index = log.history.firstIndex(where: { $0.id == session.id }) {
                    log.history[index].healthID = healthID
                }
            }
        }
    }
}
