import SwiftUI
import MapKit
import WorkingOutKit

struct RunEditor: View {
    @ObservedObject var gym: GymLog
    @ObservedObject var tracker: RunLocationTracker
    @ObservedObject var health: TrainingStore
    var display: TrainingPresentation
    var mirror: (RunRecord) -> Void
    @State private var discard = false

    var body: some View {
        List {
            if let run = gym.log.activeRun {
                Section {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        RunMetrics(run: run, date: context.date, display: display)
                    }
                    if run.paused == nil, tracker.waitingForSignal { Text(display.text("gpsWaiting")) }
                    if !tracker.authorized { Text(display.text("gpsUnavailable")) }
                    Button(display.text(run.paused == nil ? "pause" : "resume")) {
                        let date = Date.now
                        gym.update { log in
                            if log.activeRun?.paused == nil { log.activeRun?.paused = date }
                            else { log.activeRun?.resume(at: date) }
                        }
                    }
                    Button(display.text("finish")) { finish(run) }
                    Button(display.text("discard"), role: .destructive) { discard = true }
                }
                RunRoute(run: run, display: display)
            } else {
                Section(display.text("gps")) {
                    Text(display.text("gpsGuide"))
                    if tracker.authorized {
                        Button(display.text("startGPSRun"), systemImage: "location.fill") {
                            gym.update { $0.activeRun = RunRecord(date: .now) }
                        }
                    } else if tracker.authorization == .notDetermined {
                        Button(display.text("gpsPermission")) { tracker.requestPermission() }
                    } else {
                        Text(display.text("gpsUnavailable"))
                    }
                }
            }
            Section(display.text("externalRun")) {
                Text(display.text("garminGuide"))
                Button(display.text("healthRefresh")) { Task { await health.refresh(reportErrors: true) } }
            }
        }
        .navigationTitle(display.text("running"))
        .confirmationDialog(display.text("discardQuestion"), isPresented: $discard, titleVisibility: .visible) {
            Button(display.text("discard"), role: .destructive) { gym.update { $0.activeRun = nil } }
        }
    }

    private func finish(_ active: RunRecord) {
        let date = Date.now
        var run = active
        if run.paused != nil {
            run.resume(at: date)
            run.finishDate = date
        } else {
            run.finishDate = date
        }
        if gym.update({ log in
            var runs = log.runs ?? []
            runs.append(run)
            log.runs = runs
            log.activeRun = nil
        }) { mirror(run) }
    }
}

struct RunMetrics: View {
    var run: RunRecord
    var date: Date
    var display: TrainingPresentation

    var body: some View {
        let elapsed = run.elapsed(at: date)
        LabeledContent(display.text("duration"), value: display.duration(elapsed))
        if let meters = run.meters {
            LabeledContent(display.text("gpsDistance"), value: display.distanceText(meters))
            if let pace = TrainingMetrics.runningPaceSeconds(duration: elapsed, kilometers: display.distance.display(meters)) {
                LabeledContent(display.text("averagePace"), value: "\(display.duration(Double(pace))) / \(display.distance.rawValue)")
            }
        }
        if run.finishDate == nil, run.paused == nil, let newest = run.points.last,
           elapsed - newest.elapsed < 20,
           let previous = run.points.dropLast().last, !newest.newSegment,
           let pace = TrainingMetrics.runningPaceSeconds(duration: newest.elapsed - previous.elapsed, kilometers: display.distance.display(newest.meters - previous.meters)) {
            LabeledContent(display.text("currentPace"), value: "\(display.duration(Double(pace))) / \(display.distance.rawValue)")
        }
    }
}

struct RunRoute: View {
    var run: RunRecord
    var display: TrainingPresentation

    var body: some View {
        let segments = run.points.reduce(into: [[CLLocationCoordinate2D]]()) { result, point in
            if point.newSegment || result.isEmpty { result.append([]) }
            result[result.count - 1].append(.init(latitude: point.latitude, longitude: point.longitude))
        }.filter { $0.count > 1 }
        if !segments.isEmpty {
            Section(display.text("route")) {
                Map {
                    ForEach(segments.indices, id: \.self) { index in
                        MapPolyline(coordinates: segments[index]).stroke(TrainingDesign.lime, lineWidth: 4)
                    }
                }
                .frame(height: 230)
                .accessibilityLabel(display.text("route"))
            }
        }
        let splits = run.splits(unit: display.distance)
        if !splits.isEmpty {
            Section(display.text("splits")) {
                ForEach(splits.indices, id: \.self) { index in
                    LabeledContent("\((index + 1).formatted(.number.locale(display.locale))) \(display.distance.rawValue)",
                                   value: display.duration(splits[index]))
                }
            }
        }
    }
}
