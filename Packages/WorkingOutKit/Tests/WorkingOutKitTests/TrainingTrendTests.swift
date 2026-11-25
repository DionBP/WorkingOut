import Foundation
import XCTest
@testable import WorkingOutKit

final class TrainingTrendTests: XCTestCase {
    func testCalendarWeeksCombineSessionsAndKeepInvalidValuesOut() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        calendar.firstWeekday = 2
        let monday = try XCTUnwrap(calendar.date(from: .init(year: 2026, month: 11, day: 23)))
        let end = try XCTUnwrap(calendar.date(byAdding: .day, value: 30, to: monday))
        let samples = [
            TrainingTrend.Sample(date: monday, value: 40),
            .init(date: monday.addingTimeInterval(86_400), value: 60),
            .init(date: monday.addingTimeInterval(7 * 86_400), value: 30),
            .init(date: monday, value: .infinity),
            .init(date: monday, value: -5)
        ]
        let trend = TrainingTrend.aggregate(samples, in: DateInterval(start: monday, end: end), calendar: calendar)
        XCTAssertEqual(trend.period, .week)
        XCTAssertEqual(trend.buckets.map(\.date), [monday, monday.addingTimeInterval(7 * 86_400)])
        XCTAssertEqual(trend.buckets.map(\.value), [100, 30])
    }

    func testLongHistoryUsesAnnualBuckets() throws {
        let calendar = Calendar(identifier: .gregorian)
        let first = try XCTUnwrap(calendar.date(from: .init(year: 2021, month: 2)))
        let next = try XCTUnwrap(calendar.date(from: .init(year: 2024, month: 2)))
        let trend = TrainingTrend.aggregate([.init(date: first, value: 1), .init(date: next, value: 2)], calendar: calendar)
        XCTAssertEqual(trend.period, .year)
        XCTAssertEqual(trend.buckets.map(\.value), [1, 2])
    }
}
