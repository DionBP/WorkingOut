import SwiftUI
import WorkingOutKit

struct WeeklyPrograms: View {
    let display: TrainingPresentation
    let calendar: Calendar
    @ObservedObject var gym: GymLog
    let start: (ProgramOccurrence) -> Void
    @State private var moving: ProgramOccurrence?
    @State private var rescheduleDate = Date.now
    @State private var skipping: ProgramOccurrence?

    var body: some View {
        if let week = calendar.dateInterval(of: .weekOfYear, for: .now) {
            let schedule = ProgramSchedule.occurrences(programs: gym.log.programs ?? [],
                                                       overrides: gym.log.scheduleOverrides ?? [], in: week, calendar: calendar)
            let completed = Set(gym.log.history.compactMap(\.occurrenceID))
            let today = schedule.filter { calendar.isDateInToday($0.date) }
            TrainingDesign.card {
                Label(display.text("todayWorkout"), systemImage: "calendar").font(.headline)
                if today.isEmpty { Text(display.text("noScheduledWorkout")).foregroundStyle(.secondary) }
                ForEach(today) { workout in
                    workoutRow(workout, completed: completed.contains(workout.id), showDate: false)
                }
            }
            if !schedule.isEmpty {
                TrainingDesign.card {
                    Text(display.text("weeklyPlan")).font(.headline)
                    ForEach(schedule.filter { !calendar.isDateInToday($0.date) }) { workout in
                        workoutRow(workout, completed: completed.contains(workout.id), showDate: true)
                    }
                }
            }
        }
    }

    private func workoutRow(_ workout: ProgramOccurrence, completed: Bool, showDate: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if showDate {
                Text(workout.date.formatted(.dateTime.weekday(.wide).day().month().locale(display.locale)))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Text(workout.day.name).font(.title3.bold())
            Text(workout.program.name).foregroundStyle(.secondary)
            if completed {
                Label(display.text("completedWorkout"), systemImage: "checkmark.circle")
            } else {
                if !showDate {
                    Button(display.text("startProgram"), systemImage: "play.fill") { start(workout) }
                        .buttonStyle(.borderedProminent)
                        .disabled(gym.log.started != nil || !gym.log.exercises.isEmpty)
                }
                Menu(display.text("edit")) {
                    Button(display.text("reschedule")) {
                        rescheduleDate = max(workout.date, calendar.startOfDay(for: .now))
                        moving = workout
                    }
                    Button(display.text("skipWorkout"), role: .destructive) { skipping = workout }
                }.disabled(gym.log.activeOccurrenceID == workout.id)
            }
        }
        .padding(.vertical, 4)
        .confirmationDialog(display.text("skipWorkout"), isPresented: Binding(
            get: { skipping?.id == workout.id }, set: { if !$0 { skipping = nil } }
        )) {
            Button(display.text("skipWorkout"), role: .destructive) {
                gym.changeSchedule(workout, date: workout.date, skip: true)
            }
        }
        .sheet(isPresented: Binding(get: { moving?.id == workout.id }, set: { if !$0 { moving = nil } })) {
            NavigationStack {
                Form {
                    DatePicker(display.text("date"), selection: $rescheduleDate,
                               in: calendar.startOfDay(for: .now)..., displayedComponents: .date)
                }
                .navigationTitle(display.text("reschedule"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(display.text("cancel")) { moving = nil } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(display.text("save")) {
                            gym.changeSchedule(workout, date: calendar.startOfDay(for: rescheduleDate), skip: false)
                            moving = nil
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}
