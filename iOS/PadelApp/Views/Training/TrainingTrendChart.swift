import SwiftUI
import Charts
import WorkingOutKit

struct TrainingTrendChart: View {
    let title: String
    let display: TrainingPresentation
    let calendar: Calendar
    let samples: [TrainingTrend.Sample]
    let extent: DateInterval?
    let format: (Double) -> String
    let convert: (Double) -> Double
    @State private var selected: String?

    var body: some View {
        let trend = TrainingTrend.aggregate(samples, in: extent, calendar: calendar)
        let buckets = trend.buckets
        let selectedIndex = selected.flatMap(Int.init).flatMap { buckets.indices.contains($0) ? $0 : nil }
        let indexes = stride(from: 0, to: buckets.count, by: max(1, (buckets.count + 3) / 4)).map(String.init)
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            Text(selectedIndex.map { format(buckets[$0].value) } ?? format(buckets.reduce(0) { $0 + $1.value }))
                .font(.largeTitle.weight(.heavy)).monospacedDigit()
                .contentTransition(.numericText())
            Text(selectedIndex.map { label(buckets[$0].date, period: trend.period, full: true) }
                ?? display.text("bucket." + trend.period.rawValue))
                .font(.subheadline).foregroundStyle(.secondary)
                .accessibilityIdentifier("workingout.trend.period")
            Chart {
                ForEach(buckets.indices, id: \.self) { index in
                    let bucket = buckets[index]
                    BarMark(x: .value(display.text("date"), String(index)),
                            y: .value(title, convert(bucket.value)))
                        .foregroundStyle(Color.primary.opacity(selectedIndex == nil || selectedIndex == index ? 0.93 : 0.24))
                        .cornerRadius(4)
                        .accessibilityLabel(label(bucket.date, period: trend.period, full: true))
                        .accessibilityValue(format(bucket.value))
                }
            }
            .chartXAxis {
                AxisMarks(values: indexes) { value in
                    AxisValueLabel {
                        if let raw = value.as(String.self), let index = Int(raw), buckets.indices.contains(index) {
                            Text(label(buckets[index].date, period: trend.period, full: false))
                        }
                    }
                }
            }
            .chartXSelection(value: $selected)
            .frame(height: 195)
            .accessibilityLabel(title)
            Text(display.text("chartActivePeriods"))
                .font(.caption).foregroundStyle(.secondary)
        }
        .modifier(TrainingPanel())
        .onChange(of: buckets.map(\.date)) { _, _ in selected = nil }
    }

    private func label(_ date: Date, period: TrainingTrend.Period, full: Bool) -> String {
        let style = Date.FormatStyle().locale(display.locale)
        switch period {
        case .day, .week: return date.formatted(full ? style.day().month().year() : style.day().month(.abbreviated))
        case .month: return date.formatted(full ? style.month(.wide).year() : style.month(.abbreviated))
        case .year: return date.formatted(style.year())
        }
    }
}
