import Foundation

public struct RunPoint: Codable, Sendable {
    public let latitude: Double
    public let longitude: Double
    public let elapsed: TimeInterval
    public let meters: Double
    public let newSegment: Bool

    public init(latitude: Double, longitude: Double, elapsed: TimeInterval, meters: Double, newSegment: Bool) {
        self.latitude = latitude
        self.longitude = longitude
        self.elapsed = elapsed
        self.meters = meters
        self.newSegment = newSegment
    }
}

public struct RunRecord: Codable, Identifiable, Sendable {
    public var id = UUID()
    public var date: Date
    public var finishDate: Date?
    public var paused: Date?
    public var pausedSeconds: TimeInterval = 0
    public var points: [RunPoint] = []
    public var healthID: UUID?

    public init(date: Date) {
        self.date = date
    }

    public var meters: Double? { points.last.flatMap { $0.meters > 0 ? $0.meters : nil } }

    public func elapsed(at date: Date) -> TimeInterval {
        max(0, (finishDate ?? paused ?? date).timeIntervalSince(self.date) - pausedSeconds)
    }

    public mutating func resume(at date: Date) {
        guard let paused else { return }
        pausedSeconds += max(0, date.timeIntervalSince(paused))
        self.paused = nil
    }

    /// Elapsed time from the first GPS fix to a distance covered without a signal gap.
    public func timeTo(meters target: Double) -> TimeInterval? {
        guard finishDate != nil, target.isFinite, target > 0, let origin = points.first else { return nil }
        for (start, end) in zip(points, points.dropFirst()) {
            guard !end.newSegment else { return nil }
            if start.meters < target, end.meters >= target {
                let fraction = (target - start.meters) / (end.meters - start.meters)
                let duration = start.elapsed + (end.elapsed - start.elapsed) * fraction - origin.elapsed
                return duration > 0 ? duration : nil
            }
        }
        return nil
    }

    public func splits(unit: DistanceUnit) -> [TimeInterval] {
        let interval = unit == .km ? 1_000.0 : 1_609.344
        var splits: [TimeInterval] = []
        var previousSplit: TimeInterval = 0
        var target = interval
        for (start, end) in zip(points, points.dropFirst()) where !end.newSegment && end.meters > start.meters {
            while target > start.meters && target <= end.meters {
                let fraction = (target - start.meters) / (end.meters - start.meters)
                let crossing = start.elapsed + (end.elapsed - start.elapsed) * fraction
                splits.append(crossing - previousSplit)
                previousSplit = crossing
                target += interval
            }
        }
        return splits
    }
}
