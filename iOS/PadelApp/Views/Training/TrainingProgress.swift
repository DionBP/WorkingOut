import SwiftUI
import Charts
import WorkingOutKit

struct TrainingProgress: View {
    @ObservedObject var gym: GymLog
    @ObservedObject var health: TrainingStore
    var display: TrainingPresentation
    var activities: [TrainingActivity]
    var calendar: Calendar

    @AppStorage("workingout.progress.range") private var range = 0
    @AppStorage("workingout.progress.customStart") private var customStart = 0.0
    @AppStorage("workingout.progress.customEnd") private var customEnd = 0.0
    @State private var running: Bool = {
        #if DEBUG && targetEnvironment(simulator)
        return TrainingScreenshotFixtures.screen == "running"
        #else
        return false
        #endif
    }()
    @State private var exerciseID = ""

    private var startDate: Date {
        customStart == 0 ? (calendar.date(byAdding: .day, value: -29, to: .now) ?? .now)
            : Date(timeIntervalSince1970: customStart)
    }

    private var endDate: Date { customEnd == 0 ? .now : Date(timeIntervalSince1970: customEnd) }

    private var interval: DateInterval? {
        let start: Date
        let end: Date
        if range == 0 { return nil }
        if range == -1 {
            start = calendar.startOfDay(for: startDate)
            end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate
        } else {
            start = calendar.date(byAdding: .day, value: 1 - range, to: calendar.startOfDay(for: .now)) ?? .distantPast
            end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) ?? .now
        }
        return DateInterval(start: start, end: max(start, end))
    }

    var body: some View {
        let window = interval
        let entries = activities.filter { activity in
            activity.running == running && (window.map { $0.start <= activity.date && activity.date < $0.end } ?? true)
        }
        TrainingDesign.page {
            controls
            if entries.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "chart.bar.xaxis").font(.title)
                    Text(display.text("emptyProgress")).foregroundStyle(.secondary)
                }.modifier(TrainingPanel())
            } else {
                metrics(entries)
                if running { runningAnalytics(entries, interval: window) }
                else { strengthAnalytics(entries, interval: window) }
                VStack(alignment: .leading, spacing: 8) {
                    TrainingDesign.section(display.text("history"))
                    ForEach(entries) { activity in
                        TrainingActivityLink(activity: activity, gym: gym, health: health, display: display)
                        if activity.id != entries.last?.id { Divider() }
                    }
                }
            }
        }
        .navigationTitle(display.text("progress"))
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(display.text("workouts"), selection: $running) {
                Text(display.text("strength")).tag(false)
                Text(display.text("running")).tag(true)
            }.pickerStyle(.segmented)
            HStack {
                Text(display.text("dateRange")).font(.subheadline.weight(.semibold))
                Spacer()
                Picker(display.text("dateRange"), selection: $range) {
                    ForEach([0, 7, 30, 90, 365, -1], id: \.self) { days in
                        Text(display.text("range." + String(days))).tag(days)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .accessibilityLabel(display.text("dateRange"))
                .accessibilityIdentifier("workingout.progress.period")
            }
            if range == -1 {
                DatePicker(display.text("startDate"), selection: Binding(get: { startDate }, set: {
                    customStart = $0.timeIntervalSince1970
                }), in: ...endDate, displayedComponents: .date)
                DatePicker(display.text("endDate"), selection: Binding(get: { endDate }, set: {
                    customEnd = $0.timeIntervalSince1970
                }), in: startDate..., displayedComponents: .date)
            }
        }.modifier(TrainingPanel())
    }

    private func metrics(_ entries: [TrainingActivity]) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 9) { metricCards(entries) }
            VStack(spacing: 9) { metricCards(entries) }
        }
    }

    @ViewBuilder private func metricCards(_ entries: [TrainingActivity]) -> some View {
        TrainingMetric(label: display.text("workouts"), value: display.number(Double(entries.count), precision: 0), icon: "checkmark.circle")
        let durations = entries.compactMap(\.duration)
        if !durations.isEmpty {
            TrainingMetric(label: display.text("duration"), value: display.duration(durations.reduce(0, +)), icon: "clock")
        }
    }

    @ViewBuilder private func strengthAnalytics(_ entries: [TrainingActivity], interval: DateInterval?) -> some View {
        let sessions = entries.compactMap(\.strength)
        let volume = sessions.map { TrainingTrend.Sample(date: $0.date, value: $0.volume) }
        if !volume.isEmpty {
            TrainingTrendChart(title: display.text("volume"), display: display, calendar: calendar,
                               samples: volume, extent: interval, format: display.weightText,
                               convert: display.weight.display)
                .id("strength-\(range)")
            exerciseChart(sessions)
            muscleSummary(sessions)
        } else {
            TrainingTrendChart(title: display.text("workouts"), display: display, calendar: calendar,
                               samples: entries.map { .init(date: $0.date, value: 1) }, extent: interval,
                               format: { display.number($0, precision: 0) }, convert: { $0 })
                .id("strength-count-\(range)")
        }
        let records = StrengthRecord.best(in: entries)
        if !records.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                TrainingDesign.section(display.text("records"))
                ForEach(records) { record in
                    TrainingRecordLink(title: display.name(record.exercise, custom: gym.log.customExercises ?? []),
                                       value: display.weightText(record.load), activity: record.activity,
                                       gym: gym, health: health, display: display)
                }
            }
        }
    }

    @ViewBuilder private func runningAnalytics(_ entries: [TrainingActivity], interval: DateInterval?) -> some View {
        let known = entries.filter { $0.meters.map { $0.isFinite && $0 > 0 } == true }
        let samples = known.compactMap { activity in
            activity.meters.map { TrainingTrend.Sample(date: activity.date, value: $0) }
        }
        if !samples.isEmpty {
            TrainingTrendChart(title: display.text("runningDistance"), display: display, calendar: calendar,
                               samples: samples, extent: interval, format: display.distanceText,
                               convert: display.distance.display)
                .id("running-\(range)")
            let timed = known.filter { ($0.duration ?? 0) > 0 }
            if let pace = TrainingMetrics.runningPaceSeconds(duration: timed.compactMap(\.duration).reduce(0, +),
                                                              kilometers: display.distance.display(timed.compactMap(\.meters).reduce(0, +))) {
                TrainingMetric(label: display.text("averagePace"),
                               value: "\(display.duration(Double(pace))) / \(display.distance.rawValue)", icon: "speedometer")
            }
            runningRecords(known)
        } else {
            TrainingTrendChart(title: display.text("workouts"), display: display, calendar: calendar,
                               samples: entries.map { .init(date: $0.date, value: 1) }, extent: interval,
                               format: { display.number($0, precision: 0) }, convert: { $0 })
                .id("running-count-\(range)")
        }
    }

    private func runningRecords(_ entries: [TrainingActivity]) -> some View {
        let distances = [1_000.0, 1_609.344, 5_000, 10_000, 21_097.5, 42_195]
        let longest = entries.max { ($0.meters ?? 0) < ($1.meters ?? 0) }
        let records = distances.compactMap { target -> (Double, TrainingActivity, TimeInterval)? in
            entries.compactMap { activity in
                activity.run?.timeTo(meters: target).map { (target, activity, $0) }
            }.min { $0.2 < $1.2 }
        }
        return VStack(alignment: .leading, spacing: 8) {
            TrainingDesign.section(display.text("records"))
            if let longest, let meters = longest.meters {
                TrainingRecordLink(title: display.text("longestRun"), value: display.distanceText(meters), activity: longest,
                                   gym: gym, health: health, display: display)
            }
            if !records.isEmpty {
                Text(display.text("gpsRecordDescription")).font(.footnote).foregroundStyle(.secondary)
                ForEach(records.indices, id: \.self) { index in
                    let (distance, activity, time) = records[index]
                    TrainingRecordLink(title: display.distanceText(distance), value: display.duration(time), activity: activity,
                                       gym: gym, health: health, display: display)
                }
            }
        }
    }

    private func muscleSummary(_ sessions: [StrengthSession]) -> some View {
        let counts = sessions.flatMap(\.exercises).reduce(into: [String: Int]()) { counts, exercise in
            guard let id = exercise.exerciseID, let definition = ExerciseCatalog.byID[id] else { return }
            let completed = exercise.sets.filter { $0.metric.isValid && $0.warmup != true }.count
            if completed > 0 { counts[definition.primary, default: 0] += completed }
        }
        return VStack(alignment: .leading, spacing: 12) {
            TrainingDesign.section(display.text("setsByMuscle"))
            if counts.isEmpty {
                Text(display.text("emptyMuscle")).foregroundStyle(.secondary)
            } else {
                Chart {
                    ForEach(counts.keys.sorted(), id: \.self) { muscle in
                        BarMark(x: .value(display.text("workSets"), counts[muscle, default: 0]),
                                y: .value(display.text("muscle"), display.text("muscle." + muscle)))
                    }
                }.foregroundStyle(Color.primary).frame(height: CGFloat(max(counts.count * 32, 120)))
            }
        }.modifier(TrainingPanel())
    }


    private func exerciseChart(_ strength: [StrengthSession]) -> some View {
        let choices = Dictionary(grouping: strength.flatMap(\.exercises), by: \.identity)
        let values = strength.compactMap { session -> (date: Date, best: Double, estimate: Double?)? in
            let sets = session.exercises.filter { $0.identity == exerciseID }.flatMap(\.sets)
                .filter { $0.warmup != true && $0.kg > 0 }.map(\.metric)
            return TrainingMetrics.heaviestWeight(sets).map {
                (session.date, $0, sets.compactMap(TrainingMetrics.estimatedOneRepMax).max())
            }
        }.sorted { $0.date < $1.date }
        return VStack(alignment: .leading, spacing: 12) {
            Picker(display.text("exerciseProgress"), selection: $exerciseID) {
                Text(display.text("selectExercise")).tag("")
                ForEach(choices.keys.sorted(), id: \.self) { key in
                    if let exercise = choices[key]?.first {
                        Text(display.name(exercise, custom: gym.log.customExercises ?? [])).tag(key)
                    }
                }
            }
            if !exerciseID.isEmpty {
                let sets = strength.flatMap(\.exercises).filter { $0.identity == exerciseID }
                    .flatMap(\.sets).filter { $0.warmup != true && $0.kg > 0 }.map(\.metric)
                if let best = TrainingMetrics.heaviestWeight(sets) {
                    LabeledContent(display.text("heaviest"), value: display.weightText(best))
                }
                if let estimate = sets.compactMap(TrainingMetrics.estimatedOneRepMax).max() {
                    LabeledContent(display.text("estimatedMax"), value: display.weightText(estimate))
                }
                if values.count > 1 {
                    Chart {
                        ForEach(values.indices, id: \.self) { index in
                            LineMark(x: .value(display.text("date"), values[index].date),
                                     y: .value(display.text("weight"), display.weight.display(values[index].best)))
                                .foregroundStyle(by: .value(display.text("weight"), display.text("heaviest")))
                            PointMark(x: .value(display.text("date"), values[index].date),
                                      y: .value(display.text("weight"), display.weight.display(values[index].best)))
                                .foregroundStyle(by: .value(display.text("weight"), display.text("heaviest")))
                            if let estimate = values[index].estimate {
                                LineMark(x: .value(display.text("date"), values[index].date),
                                         y: .value(display.text("weight"), display.weight.display(estimate)))
                                    .foregroundStyle(by: .value(display.text("weight"), display.text("estimatedMax")))
                                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
                            }
                        }
                    }
                    .chartForegroundStyleScale([display.text("heaviest"): Color.primary,
                                                display.text("estimatedMax"): Color.secondary])
                    .frame(height: 180)
                }
            }
        }.modifier(TrainingPanel())
    }
}
