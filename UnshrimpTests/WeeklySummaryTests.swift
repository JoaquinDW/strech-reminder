import XCTest
@testable import Unshrimp

final class WeeklySummaryTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 2
        return c
    }()

    private func date(_ day: Int, _ hour: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    func testCountsOnlyTheWeekAndSumsPlannedMinutes() {
        let breaks = [
            BreakRecord(date: date(1), minutes: 5, focus: [.lowerBack], energy: 10), // Sunday, previous week
            BreakRecord(date: date(2), minutes: 3, focus: [.neck], energy: 10),
            BreakRecord(date: date(2, 14), minutes: 3, focus: [.neck, .shoulders], energy: 10),
            BreakRecord(date: date(4), minutes: 2, focus: [.neck], energy: 10)
        ]
        let s = WeeklySummary(breaks: breaks, weekContaining: date(4), goal: 2, now: date(4, 18), calendar: calendar)
        XCTAssertEqual(s.minutes, 8)
        XCTAssertEqual(s.breaks, 3)
        XCTAssertEqual(s.activeDays, 2)
        XCTAssertEqual(s.goalDays, 1)
        XCTAssertEqual(s.topArea, .neck)
        XCTAssertTrue(s.isCurrent)
        XCTAssertEqual(s.days.map(\.minutes), [6, 0, 2, 0, 0, 0, 0])
        XCTAssertEqual(s.days.filter(\.isFuture).count, 4)
    }

    func testEmptyWeekHasNoTopArea() {
        let s = WeeklySummary(breaks: [], weekContaining: date(4), goal: 3, now: date(20), calendar: calendar)
        XCTAssertTrue(s.isEmpty)
        XCTAssertNil(s.topArea)
        XCTAssertFalse(s.isCurrent)
    }
}
