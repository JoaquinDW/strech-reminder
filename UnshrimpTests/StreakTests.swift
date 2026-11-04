import XCTest
@testable import Unshrimp

final class StreakTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 2
        return c
    }()

    /// Mon–Fri. November 2, 2026 is a Monday.
    private let workdays: Set<Int> = [2, 3, 4, 5, 6]

    private func day(_ d: Int) -> DayKey { DayKey(value: 20261100 + d) }

    private func engine(_ days: [Int], workdays: Set<Int>? = nil) -> StreakEngine {
        StreakEngine(active: Set(days.map(day)), workdays: workdays ?? self.workdays, calendar: calendar)
    }

    // MARK: Day keys

    func testDayKeyCrossesMonths() {
        XCTAssertEqual(DayKey(value: 20261130).adding(1, calendar: calendar), DayKey(value: 20261201))
        XCTAssertEqual(DayKey(value: 20260301).adding(-1, calendar: calendar), DayKey(value: 20260228))
        XCTAssertEqual(day(2).weekday(calendar), 2)
        XCTAssertEqual(day(2).days(to: day(9), calendar: calendar), 7)
    }

    // MARK: Counting

    func testCountsConsecutiveWorkdays() {
        let e = engine([2, 3, 4, 5])
        XCTAssertEqual(e.current(asOf: day(5), state: StreakState()), 4)
        // Friday before its first break: still four, and at risk.
        XCTAssertEqual(e.current(asOf: day(6), state: StreakState()), 4)
        XCTAssertTrue(e.atRisk(today: day(6), state: StreakState()))
        XCTAssertFalse(e.atRisk(today: day(5), state: StreakState()))
    }

    func testWeekendWithoutBreaksDoesNotBreakIt() {
        let e = engine([5, 6, 9])
        XCTAssertEqual(e.current(asOf: day(9), state: StreakState()), 3)
        XCTAssertEqual(e.current(asOf: day(7), state: StreakState()), 2)
        XCTAssertFalse(e.atRisk(today: day(7), state: StreakState()), "A day off is never at risk")
    }

    func testBreakOnADayOffAddsToIt() {
        XCTAssertEqual(engine([6, 7, 9]).current(asOf: day(9), state: StreakState()), 3)
    }

    func testMissedWorkdayEndsIt() {
        XCTAssertEqual(engine([2, 3, 5]).current(asOf: day(5), state: StreakState()), 1)
        XCTAssertEqual(engine([2, 3]).current(asOf: day(5), state: StreakState()), 0)
    }

    func testLongestStreak() {
        XCTAssertEqual(engine([2, 3, 4, 5, 9, 10]).longest(through: day(10), state: StreakState()), 4)
    }

    // MARK: Shell guards and misses

    func testShellGuardCoversAMissedDay() {
        let e = engine([2, 3])
        var state = StreakState()
        state.checkedThrough = day(3)
        state.freezes = 1
        let events = e.reconcile(&state, today: day(5))
        XCTAssertEqual(events, [.frozen(days: 1, streak: 2)])
        XCTAssertEqual(state.freezes, 0)
        XCTAssertEqual(state.checkedThrough, day(4))
        XCTAssertEqual(state.notice, .frozen(days: 1, streak: 2))
        // Thursday's first break: Wednesday was covered, so the streak carries on.
        XCTAssertEqual(engine([2, 3, 5]).current(asOf: day(5), state: state), 3)
    }

    func testNotEnoughGuardsKeepsThemAndLosesTheStreak() {
        let e = engine([2, 3])
        var state = StreakState()
        state.checkedThrough = day(3)
        state.freezes = 1
        let events = e.reconcile(&state, today: day(6))
        XCTAssertEqual(events, [.lost(previous: 2)])
        XCTAssertEqual(state.freezes, 1, "Guards aren't spent on a streak they can't save")
        XCTAssertEqual(Set(state.missed), [day(4), day(5)])
        XCTAssertNil(state.repair, "Two missed days can't be won back")
    }

    func testReconcileIsIdempotent() {
        let e = engine([2, 3])
        var state = StreakState()
        state.checkedThrough = day(3)
        state.freezes = 2
        e.reconcile(&state, today: day(5))
        let once = state
        XCTAssertEqual(e.reconcile(&state, today: day(5)), [])
        XCTAssertEqual(state, once)
    }

    func testRepairWinsBackOneMissedDay() {
        let e = engine([2, 3, 4])
        var state = StreakState()
        state.checkedThrough = day(4)
        XCTAssertEqual(e.reconcile(&state, today: day(6)), [.lost(previous: 3)])
        XCTAssertEqual(state.repair, StreakRepairOffer(day: day(5), previous: 3, expires: day(6)))

        let withFriday = engine([2, 3, 4, 6])
        XCTAssertEqual(withFriday.current(asOf: day(6), state: state), 1)
        XCTAssertNil(withFriday.applyRepair(&state, today: day(6), goalMet: false))
        XCTAssertEqual(withFriday.applyRepair(&state, today: day(6), goalMet: true), .repaired(streak: 4))
        XCTAssertEqual(withFriday.current(asOf: day(6), state: state), 4, "The won-back day keeps the run going without adding to it")
        XCTAssertNil(state.repair)
        XCTAssertEqual(state.lastRepair, day(6))
    }

    func testRepairOfferExpiresAndCoolsDown() {
        let e = engine([2, 3, 4])
        var state = StreakState()
        state.checkedThrough = day(4)
        e.reconcile(&state, today: day(6))
        XCTAssertNotNil(state.repair)
        XCTAssertEqual(e.reconcile(&state, today: day(7)), [], "Friday's miss doesn't lose the streak a second time")
        XCTAssertNil(state.repair, "Gone once its day has passed")

        var cooling = StreakState()
        cooling.checkedThrough = day(4)
        cooling.lastRepair = day(1)
        e.reconcile(&cooling, today: day(6))
        XCTAssertNil(cooling.repair, "Only one repair every 30 days")
    }

    func testFirstRunRecordsThePastQuietly() {
        let e = engine([2, 3, 5, 6, 9])
        var state = StreakState()
        XCTAssertEqual(e.reconcile(&state, today: day(10)), [])
        XCTAssertEqual(state.missed, [day(4)])
        XCTAssertEqual(state.checkedThrough, day(9))
        XCTAssertEqual(e.current(asOf: day(10), state: state), 3)
        XCTAssertEqual(state.best, 3)
    }

    func testChangingWorkdaysNeverRewritesThePast() {
        let e = engine([6, 9])
        var state = StreakState()
        state.checkedThrough = day(6)
        e.reconcile(&state, today: day(9))
        // Now every day is a workday, but the weekend already counted as days off.
        let everyDay = engine([6, 9], workdays: Set(1...7))
        XCTAssertEqual(everyDay.current(asOf: day(9), state: state), 2)
    }

    // MARK: Milestones

    func testMilestonesGiveGuardsAndWearables() {
        let e = engine([])
        var state = StreakState()
        XCTAssertEqual(e.reachMilestones(&state, streak: 2), [])
        XCTAssertEqual(e.reachMilestones(&state, streak: 7), [3, 7])
        XCTAssertEqual(state.freezes, 2)
        XCTAssertEqual(e.reachMilestones(&state, streak: 7), [], "Each milestone counts once")
        XCTAssertEqual(e.reachMilestones(&state, streak: 14), [14])
        XCTAssertEqual(state.freezes, StreakRules.maxFreezes, "Never more than the cap")
        XCTAssertEqual(StreakRules.wearable(forMilestone: 7), .cap)
        XCTAssertNil(StreakRules.wearable(forMilestone: 3))
        XCTAssertEqual(StreakRules.wearable(forMilestone: 200), .shades)
        XCTAssertEqual(StreakRules.wearable(forMilestone: 365), .coralCrown)
        XCTAssertEqual(StreakRules.nextMilestone(after: 7), 14)
    }

    func testCalendarKinds() {
        let e = engine([2, 3, 5])
        var state = StreakState()
        state.checkedThrough = day(3)
        state.freezes = 1
        e.reconcile(&state, today: day(5))
        let goal: (DayKey) -> Bool = { $0 == self.day(3) }
        XCTAssertEqual(e.kind(of: day(2), today: day(6), state: state, goalFor: goal), .done(perfect: false))
        XCTAssertEqual(e.kind(of: day(3), today: day(6), state: state, goalFor: goal), .done(perfect: true))
        XCTAssertEqual(e.kind(of: day(4), today: day(6), state: state, goalFor: goal), .frozen)
        XCTAssertEqual(e.kind(of: day(6), today: day(6), state: state, goalFor: goal), .pending)
        XCTAssertEqual(e.kind(of: day(7), today: day(7), state: state, goalFor: goal), .rest)
        XCTAssertEqual(e.kind(of: day(9), today: day(6), state: state, goalFor: goal), .future)
        XCTAssertEqual(e.kind(of: day(1), today: day(6), state: state, goalFor: goal), .before)
    }

    // MARK: Persistence and reminders

    func testStateRoundTrips() throws {
        var state = StreakState()
        state.freezes = 1
        state.covered = [CoveredDay(day: day(4), kind: .freeze)]
        state.missed = [day(10)]
        state.checkedThrough = day(11)
        state.notice = .lost(previous: 4)
        state.repair = StreakRepairOffer(day: day(10), previous: 4, expires: day(12))
        let decoded = try JSONDecoder().decode(StreakState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(decoded, state)
        // Older saves have no streak at all.
        let empty = try JSONDecoder().decode(StreakState.self, from: Data("{}".utf8))
        XCTAssertEqual(empty, StreakState())
    }

    func testStreakSaveDatesSkipTodayOnceSafe() {
        var schedule = WorkSchedule()
        schedule.endMinute = 18 * 60
        let fridayMorning = calendar.date(from: DateComponents(year: 2026, month: 11, day: 6, hour: 10))!
        let pending = ReminderPlanner.streakSaveDates(after: fridayMorning, schedule: schedule, skipToday: false, calendar: calendar)
        XCTAssertEqual(pending.map { calendar.component(.day, from: $0) }, [6, 9])
        XCTAssertEqual(calendar.component(.hour, from: pending[0]), 17)
        let safe = ReminderPlanner.streakSaveDates(after: fridayMorning, schedule: schedule, skipToday: true, calendar: calendar)
        XCTAssertEqual(safe.map { calendar.component(.day, from: $0) }, [9, 10])
    }

    func testTiersFollowTheStreak() {
        XCTAssertEqual(StreakTier(streak: 0), .ripple)
        XCTAssertEqual(StreakTier(streak: 6), .ripple)
        XCTAssertEqual(StreakTier(streak: 7), .wave)
        XCTAssertEqual(StreakTier(streak: 30), .tide)
        XCTAssertEqual(StreakTier(streak: 99), .tide)
        XCTAssertEqual(StreakTier(streak: 100), .swell)
        XCTAssertEqual(StreakTier(streak: 400), .tsunami)
        XCTAssertNil(StreakTier.tsunami.next)
        for tier in StreakTier.allCases where tier != .ripple {
            XCTAssertTrue(StreakRules.milestones.contains(tier.minDays))
        }
    }

    func testTierUpOnlyWhenCrossingALevel() {
        var update = StreakUpdate(before: 6, after: 7, extended: true, best: 7, isNewBest: true)
        XCTAssertEqual(update.tierUp, .wave)
        update.before = 7
        update.after = 8
        XCTAssertNil(update.tierUp)
    }

    func testLastCallStartsBeforeTheEndOfWork() {
        var schedule = WorkSchedule()
        schedule.startMinute = 9 * 60
        schedule.endMinute = 18 * 60
        XCTAssertFalse(StreakRules.isLastCall(minuteOfDay: 15 * 60 + 59, schedule: schedule))
        XCTAssertTrue(StreakRules.isLastCall(minuteOfDay: 16 * 60, schedule: schedule))
        XCTAssertTrue(StreakRules.isLastCall(minuteOfDay: 21 * 60, schedule: schedule))
        schedule.endMinute = 10 * 60
        XCTAssertFalse(StreakRules.isLastCall(minuteOfDay: 8 * 60, schedule: schedule))
    }
}
