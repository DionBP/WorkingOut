import SwiftUI
import WorkingOutKit

struct TrainingOverview: View {
    let display: TrainingPresentation
    let calendar: Calendar
    let activities: [TrainingActivity]
    let goal: Int
    @ObservedObject var gym: GymLog
    let health: TrainingStore
    let openStrength: () -> Void
    let openRun: () -> Void
    let openPrograms: () -> Void
    let openProgress: () -> Void
    let start: (ProgramOccurrence) -> Void
    @State private var selectedDate = Date.now
    @ScaledMetric(relativeTo: .caption) private var dayWidth = 44.0

    private var activeStrength: Bool { gym.log.started != nil || !gym.log.exercises.isEmpty }

    var body: some View {
        let interval = calendar.dateInterval(of: .weekOfYear, for: .now)
        let week = activities.filter { interval?.contains($0.date) == true }
        let schedule = interval.map {
            ProgramSchedule.occurrences(programs: gym.log.programs ?? [], overrides: gym.log.scheduleOverrides ?? [],
                                        in: $0, calendar: calendar)
        } ?? []
        let finished = Set(gym.log.history.compactMap(\.occurrenceID))
        let today = schedule.first { calendar.isDateInToday($0.date) && !finished.contains($0.id) }
        TrainingDesign.page {
            todayHero(today)
            if let interval { weekPanel(interval, week: week, schedule: schedule, finished: finished) }
            if !week.isEmpty { summary(week, title: display.text("weekStats"), showCount: false) }
            else if !activities.isEmpty { summary(activities, title: display.text("historicalInsights"), showCount: true) }
            records
            recent
        }
        .navigationTitle(display.text("overview"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { masthead }
        }
        #if DEBUG && targetEnvironment(simulator)
        .onAppear { TrainingScreenshotFixtures.markRendered("overview") }
        #endif
    }

    private var masthead: some View {
        HStack(spacing: 11) {
            Image("WorkingOutLogo").resizable().scaledToFit().frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 9)).accessibilityHidden(true)
            Text("WorkingOut").font(.headline.weight(.heavy)).accessibilityAddTraits(.isHeader)
        }
    }

    private func todayHero(_ workout: ProgramOccurrence?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(display.text("todayWorkout")).font(.subheadline.weight(.semibold)).foregroundStyle(.white.opacity(0.78))
            Text(heroTitle(workout)).font(.largeTitle.weight(.heavy)).fixedSize(horizontal: false, vertical: true)
            if let workout, !activeStrength, gym.log.activeRun == nil {
                Text(workout.program.name).foregroundStyle(.white.opacity(0.78))
                primary(display.text("startProgram"), icon: "play.fill") { start(workout) }
            } else if activeStrength {
                primary(display.text("continueStrength"), icon: "play.fill", action: openStrength)
            } else if gym.log.activeRun != nil {
                primary(display.text("continueRun"), icon: "play.fill", action: openRun)
            } else {
                primary(display.text("startStrength"), icon: "play.fill", action: openStrength)
                Button(display.text("browsePrograms"), action: openPrograms)
                    .buttonStyle(.plain)
                    .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
            }
        }
        .foregroundStyle(.white)
        .padding(21)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 23)
                .fill(LinearGradient(colors: [.black, Color(white: 0.18)], startPoint: .bottomLeading, endPoint: .topTrailing))
        }
    }

    private func heroTitle(_ workout: ProgramOccurrence?) -> String {
        if activeStrength { return display.text("strength") }
        if gym.log.activeRun != nil { return display.text("running") }
        return workout?.day.name ?? display.text("noScheduledWorkout")
    }

    private func primary(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: icon) }
            .buttonStyle(TrainingCTA(inverted: true))
    }

    private func weekPanel(_ interval: DateInterval, week: [TrainingActivity], schedule: [ProgramOccurrence],
                           finished: Set<String>) -> some View {
        let selected = interval.contains(selectedDate) ? selectedDate : .now
        let dayActivities = week.filter { calendar.isDate($0.date, inSameDayAs: selected) }
        let daySchedule = schedule.filter { calendar.isDate($0.date, inSameDayAs: selected) }
        return VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                TrainingDesign.section(display.text("thisWeek"))
                Spacer(minLength: 6)
                Text("\(week.count) / \(goal)").font(.subheadline.weight(.semibold)).monospacedDigit()
                    .accessibilityLabel(display.text("weeklyGoal"))
                    .accessibilityValue("\(week.count) / \(goal)")
            }
            ProgressView(value: TrainingMetrics.weeklyProgress(completed: week.count, goal: goal)).tint(.primary)
            ViewThatFits(in: .horizontal) {
                calendarDays(interval, selected: selected, week: week, schedule: schedule)
                ScrollView(.horizontal) {
                    calendarDays(interval, selected: selected, week: week, schedule: schedule)
                }.scrollIndicators(.hidden)
            }
            Divider()
            Text(selected.formatted(.dateTime.weekday(.wide).day().month().locale(display.locale)))
                .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            if dayActivities.isEmpty && daySchedule.isEmpty {
                Text(display.text("calendarEmptyDay")).font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(dayActivities) { activity in
                TrainingActivityLink(activity: activity, gym: gym, health: health, display: display)
            }
            ForEach(daySchedule.filter { !finished.contains($0.id) }) { occurrence in
                Button(action: openPrograms) {
                    Label(occurrence.day.name, systemImage: "calendar").frame(minHeight: 44)
                }.buttonStyle(.plain)
            }
        }.modifier(TrainingPanel())
    }

    private func calendarDays(_ interval: DateInterval, selected: Date, week: [TrainingActivity],
                              schedule: [ProgramOccurrence]) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<7) { offset in
                if let day = calendar.date(byAdding: .day, value: offset, to: interval.start) {
                    dayButton(day, selected: selected, week: week, schedule: schedule)
                }
            }
        }
    }

    private func dayButton(_ date: Date, selected: Date, week: [TrainingActivity],
                           schedule: [ProgramOccurrence]) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selected)
        let worked = week.contains { calendar.isDate($0.date, inSameDayAs: date) }
        let planned = schedule.contains { calendar.isDate($0.date, inSameDayAs: date) }
        return Button { selectedDate = date } label: {
            VStack(spacing: 5) {
                Text(date.formatted(.dateTime.weekday(.narrow).locale(Locale(identifier: display.language.resolved))))
                    .font(.caption.weight(.medium))
                Text(date.formatted(.dateTime.day().locale(display.locale))).font(.subheadline.weight(.bold))
                Image(systemName: worked ? "checkmark" : (planned ? "circle.fill" : "minus"))
                    .font(.system(size: 7, weight: .semibold)).accessibilityHidden(true)
            }
            .frame(minWidth: max(44, dayWidth), maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(isSelected ? TrainingDesign.background : Color.primary)
            .background(isSelected ? Color.primary : TrainingDesign.subdued, in: RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(date.formatted(.dateTime.weekday(.wide).day().month().locale(display.locale)))
        .accessibilityValue(calendarStatus(worked: worked, planned: planned))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func calendarStatus(worked: Bool, planned: Bool) -> String {
        if worked { return display.text("completedWorkout") }
        if planned { return display.text("plannedWorkout") }
        return display.text("calendarEmptyDay")
    }

    private func summary(_ entries: [TrainingActivity], title: String, showCount: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            TrainingDesign.section(title)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { metrics(entries, showCount: showCount) }
                VStack(spacing: 8) { metrics(entries, showCount: showCount) }
            }
        }
    }

    @ViewBuilder private func metrics(_ entries: [TrainingActivity], showCount: Bool) -> some View {
        let durations = entries.compactMap(\.duration)
        if showCount || durations.isEmpty {
            TrainingMetric(label: display.text("workouts"), value: display.number(Double(entries.count), precision: 0), icon: "checkmark.circle")
        } else {
            TrainingMetric(label: display.text("duration"), value: display.compactDuration(durations.reduce(0, +)), icon: "clock")
        }
        let distance = entries.filter(\.running).compactMap(\.meters)
        let strength = entries.compactMap(\.strength)
        if !distance.isEmpty {
            TrainingMetric(label: display.text("distance"), value: display.distanceText(distance.reduce(0, +)), icon: "figure.run")
        } else if !strength.isEmpty {
            TrainingMetric(label: display.text("volume"), value: display.weightText(strength.reduce(0) { $0 + $1.volume }), icon: "dumbbell")
        } else if showCount && !durations.isEmpty {
            TrainingMetric(label: display.text("duration"), value: display.compactDuration(durations.reduce(0, +)), icon: "clock")
        }
    }

    @ViewBuilder private var records: some View {
        let strength = StrengthRecord.best(in: activities).first
        let longest = activities.filter { $0.running && ($0.meters ?? 0) > 0 }
            .max { ($0.meters ?? 0) < ($1.meters ?? 0) }
        if strength != nil || longest != nil {
            VStack(alignment: .leading, spacing: 8) {
                TrainingDesign.section(display.text("records"))
                if let record = strength {
                    TrainingRecordLink(title: display.name(record.exercise, custom: gym.log.customExercises ?? []),
                                       value: display.weightText(record.load), activity: record.activity, gym: gym,
                                       health: health, display: display)
                }
                if let longest, let meters = longest.meters {
                    TrainingRecordLink(title: display.text("longestRun"), value: display.distanceText(meters),
                                       activity: longest, gym: gym, health: health, display: display)
                }
            }
        }
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                TrainingDesign.section(display.text("recent"))
                Spacer(minLength: 8)
                if !activities.isEmpty {
                    Button(display.text("history"), action: openProgress).font(.subheadline.weight(.semibold))
                }
            }
            if activities.isEmpty { Text(display.text("emptyOverview")).foregroundStyle(.secondary) }
            ForEach(activities.prefix(3)) { activity in
                TrainingActivityLink(activity: activity, gym: gym, health: health, display: display)
            }
        }
    }
}
