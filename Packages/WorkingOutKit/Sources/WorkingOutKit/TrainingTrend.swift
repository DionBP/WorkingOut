import Foundation

public enum TrainingTrend {
    public struct Sample {
        public let date: Date
        public let value: Double

        public init(date: Date, value: Double) {
            self.date = date
            self.value = value
        }
    }

    public enum Period: String, Sendable {
        case day, week, month, year
    }

    public struct Bucket: Identifiable {
        public let date: Date
        public let value: Double
        public var id: Date { date }
    }

    /// Use a consistent calendar period across the selected window.
    public static func aggregate(_ samples: [Sample], in extent: DateInterval? = nil,
                                 calendar: Calendar) -> (period: Period, buckets: [Bucket]) {
        let valid = samples.filter { $0.value.isFinite && $0.value >= 0 }
        let start = extent?.start ?? valid.map(\.date).min() ?? .now
        let end = extent?.end ?? valid.map(\.date).max() ?? start
        let span = calendar.dateComponents([.day], from: calendar.startOfDay(for: start),
                                           to: calendar.startOfDay(for: end)).day ?? 0
        let period: Period
        let component: Calendar.Component
        switch span {
        case ...13: (period, component) = (.day, .day)
        case 14...91: (period, component) = (.week, .weekOfYear)
        case 92...450: (period, component) = (.month, .month)
        default: (period, component) = (.year, .year)
        }
        let grouped = valid.reduce(into: [Date: Double]()) { result, sample in
            guard let date = calendar.dateInterval(of: component, for: sample.date)?.start else { return }
            result[date, default: 0] += sample.value
        }
        let buckets = grouped.keys.sorted().map { Bucket(date: $0, value: grouped[$0, default: 0]) }
        return (period, buckets)
    }
}
