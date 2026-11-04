import XCTest
@testable import Unshrimp

final class StandsAndFeelingTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 2
        return c
    }()

    /// Monday 2 Nov 2026 at the given time.
    private func monday(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: hour, minute: minute))!
    }

    private var schedule: WorkSchedule {
        var s = WorkSchedule()
        s.startMinute = 9 * 60
        s.endMinute = 18 * 60
        s.intervalMinutes = 120
        return s
    }

    // MARK: Stand reminders

    func testStandsFillTheGapsAndKeepClearOfBreaks() {
        let stands = ReminderPlanner.standSlots(on: monday(0), schedule: schedule, intervalMinutes: 45, calendar: calendar)
        let breaks = ReminderPlanner.slots(on: monday(0), schedule: schedule, calendar: calendar)
        XCTAssertFalse(stands.isEmpty)
        for stand in stands {
            for b in breaks {
                XCTAssertGreaterThan(abs(stand.timeIntervalSince(b)), Double(StandRules.gapAroundBreakMinutes) * 60)
            }
            XCTAssertLessThan(stand, monday(18))
        }
        // Breaks at 11, 13, 15 and 17; stands every 45 min from 9 skip anything within 15 min of them.
        XCTAssertEqual(stands.first, monday(9, 45))
        XCTAssertFalse(stands.contains(monday(11, 15)))
    }

    func testNoStandsOnDaysOff() {
        let sunday = calendar.date(byAdding: .day, value: -1, to: monday(0))!
        XCTAssertTrue(ReminderPlanner.standSlots(on: sunday, schedule: schedule, intervalMinutes: 45, calendar: calendar).isEmpty)
    }

    func testRecentMovementQuietsTheNextStand() {
        let now = monday(10)
        let fresh = ReminderPlanner.upcomingStands(from: now, lastMove: nil, schedule: schedule, intervalMinutes: 45, days: 1, calendar: calendar)
        let afterStand = ReminderPlanner.upcomingStands(from: now, lastMove: monday(10, 10), schedule: schedule, intervalMinutes: 45, days: 1, calendar: calendar)
        XCTAssertEqual(fresh.first, monday(10, 30))
        XCTAssertNotEqual(afterStand.first, monday(10, 30))
    }

    func testIgnoredStandsPushTheNextOneLater() {
        let now = monday(10)
        let later = now.addingTimeInterval(Double(45 + StandRules.backoffMinutes) * 60)
        let slowed = ReminderPlanner.upcomingStands(from: now, lastMove: nil, schedule: schedule, intervalMinutes: 45,
                                                    notBefore: later, days: 1, calendar: calendar)
        XCTAssertTrue(slowed.allSatisfy { $0 >= later })
    }

    func testWeeklyRecapLandsBeforeTheEndOfTheLastWorkday() {
        let date = ReminderPlanner.weeklyRecapDate(after: monday(10), schedule: schedule, calendar: calendar)
        let friday = calendar.date(from: DateComponents(year: 2026, month: 11, day: 6, hour: 17))!
        XCTAssertEqual(date, friday)
        // After that moment it moves to next week.
        let next = ReminderPlanner.weeklyRecapDate(after: friday.addingTimeInterval(60), schedule: schedule, calendar: calendar)
        XCTAssertEqual(next, calendar.date(byAdding: .day, value: 7, to: friday))
    }

    func testStandEnergyIsCappedPerDay() {
        XCTAssertEqual(StandRules.energy(standsTodayEnergy: 0), StandRules.energy)
        XCTAssertEqual(StandRules.energy(standsTodayEnergy: StandRules.dailyEnergyCap - 1), 1)
        XCTAssertEqual(StandRules.energy(standsTodayEnergy: StandRules.dailyEnergyCap), 0)
    }

    func testStandPickIsStableAndCoversTheCatalog() {
        XCTAssertEqual(StandMove.pick(seed: 7), StandMove.pick(seed: 7))
        XCTAssertEqual(Set((0..<StandMove.all.count).map { StandMove.pick(seed: $0).id }).count, StandMove.all.count)
        XCTAssertEqual(Set(StandMove.all.map(\.id)).count, StandMove.all.count)
    }

    // MARK: Routines

    func testLongerBreaksIncludeAStandingMove() {
        for length in [BreakLength.three, .five] {
            for focus: Set<FocusArea> in [[.neck], [.shoulders], [.neck, .shoulders], Set(FocusArea.allCases)] {
                let routine = DemoLibrary.routine(length: length, focus: focus)
                XCTAssertTrue(routine.moves.contains { DemoLibrary.standingMoveIDs.contains($0.id) }, "\(length) \(focus)")
            }
        }
    }

    func testMovesThatBotheredSomeoneSitOut() {
        let routine = DemoLibrary.routine(length: .two, focus: [.neck], avoid: ["neck-tilt", "head-turn"])
        XCTAssertFalse(routine.moves.contains { ["neck-tilt", "head-turn"].contains($0.id) })
        XCTAssertEqual(routine.moves.count, 4)
    }

    func testAvoidingEverythingStillBuildsABreak() {
        let all = Set(DemoLibrary.availableMoves.map(\.id))
        let routine = DemoLibrary.routine(length: .three, focus: [.neck], avoid: all)
        XCTAssertEqual(routine.moves.count, 6)
    }

    // MARK: Feeling and stiffness

    func testTrendNeedsAWeekBetweenCheckins() {
        let start = monday(9)
        let records = [
            StiffnessRecord(date: start, area: .neck, score: 6),
            StiffnessRecord(date: start.addingTimeInterval(2 * 86_400), area: .neck, score: 5),
            StiffnessRecord(date: start, area: .shoulders, score: 4),
            StiffnessRecord(date: start.addingTimeInterval(14 * 86_400), area: .shoulders, score: 2)
        ]
        let trends = StiffnessTrend.trends(records)
        XCTAssertEqual(trends, [StiffnessTrend(area: .shoulders, first: 4, latest: 2)])
        XCTAssertEqual(trends.first?.change, -2)
    }

    func testWeeklySummaryCountsStandsAndLooserBreaks() {
        let breaks = [
            BreakRecord(date: monday(10), minutes: 3, focus: [.neck], energy: 10, feel: .looser),
            BreakRecord(date: monday(12), minutes: 3, focus: [.neck], energy: 10, feel: .looser),
            BreakRecord(date: monday(14), minutes: 3, focus: [.neck], energy: 10, feel: .same),
            BreakRecord(date: monday(16), minutes: 3, focus: [.neck], energy: 10)
        ]
        let stands = [StandRecord(date: monday(11), moveID: "stand-march", energy: 3),
                      StandRecord(date: monday(11).addingTimeInterval(-7 * 86_400), moveID: "stand-march", energy: 3)]
        let s = WeeklySummary(breaks: breaks, weekContaining: monday(12), goal: 3, now: monday(17), calendar: calendar,
                              stands: stands)
        XCTAssertEqual(s.stands, 1)
        XCTAssertEqual(s.feelAnswers, 3)
        XCTAssertEqual(s.looserShare?.looser, 2)
        XCTAssertEqual(s.looserShare?.of, 3)
        XCTAssertTrue(s.hasFeeling)
    }

    func testDataSavedBeforeStandsStillLoads() throws {
        let json = #"{"hasOnboarded":true,"breaks":[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","date":0,"minutes":3,"focus":["neck"],"energy":10}],"preferences":{"dailyGoal":4}}"#.data(using: .utf8)!
        let data = try JSONDecoder().decode(AppData.self, from: json)
        XCTAssertTrue(data.stands.isEmpty)
        XCTAssertTrue(data.stiffness.isEmpty)
        XCTAssertNil(data.breaks.first?.feel)
        XCTAssertTrue(data.preferences.standsEnabled)
        XCTAssertEqual(data.preferences.standIntervalMinutes, 45)
        XCTAssertEqual(data.preferences.dailyGoal, 4)
    }

    func testFrictionSetsTheStandRhythm() {
        XCTAssertEqual(Preferences.suggestedStandInterval(for: .forget), 45)
        XCTAssertEqual(Preferences.suggestedStandInterval(for: .unsure), 60)
    }
}
