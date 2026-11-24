import Foundation

/// A calendar day, independent of time zone shifts: 2026-11-04 is stored as 20261104.
struct DayKey: Hashable, Comparable, Codable {
    let value: Int

    init(value: Int) { self.value = value }

    init(_ date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        value = (c.year ?? 0) * 10_000 + (c.month ?? 0) * 100 + (c.day ?? 0)
    }

    init(from decoder: Decoder) throws {
        value = try decoder.singleValueContainer().decode(Int.self)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(value)
    }

    /// Noon on that day, so adding days never trips over a daylight saving change.
    func date(_ calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: value / 10_000, month: value / 100 % 100, day: value % 100, hour: 12)) ?? Date()
    }

    func adding(_ days: Int, calendar: Calendar = .current) -> DayKey {
        DayKey(calendar.date(byAdding: .day, value: days, to: date(calendar)) ?? date(calendar), calendar: calendar)
    }

    func weekday(_ calendar: Calendar = .current) -> Int { calendar.component(.weekday, from: date(calendar)) }

    func days(to other: DayKey, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: date(calendar), to: other.date(calendar)).day ?? 0
    }

    static func < (a: DayKey, b: DayKey) -> Bool { a.value < b.value }
}

/// The rules in one place, so they're easy to tune.
enum StreakRules {
    /// Streak lengths that get a celebration and a shell guard. Some also bring something to wear.
    static let milestones = [3, 7, 14, 30, 50, 100, 200, 365]
    /// Most shell guards Kip can keep at once.
    static let maxFreezes = 2
    /// Energy for one shell guard. Spending it never takes anything off the desk.
    static let freezeCost = 150
    /// Shortest streak worth offering a repair for.
    static let repairMinimum = 3
    /// Days between repairs.
    static let repairCooldownDays = 30

    static func wearable(forMilestone days: Int) -> Wearable? {
        Wearable.allCases.first { $0.streakMilestone == days }
    }

    static func nextMilestone(after streak: Int) -> Int? { milestones.first { $0 > streak } }

    /// Minutes before the end of work when an untouched streak starts asking for attention.
    static let lastCallMinutes = 120

    /// Late enough in the day that a streak with no break yet should say so.
    static func isLastCall(minuteOfDay: Int, schedule: WorkSchedule) -> Bool {
        minuteOfDay >= max(schedule.startMinute, schedule.endMinute - lastCallMinutes)
    }
}

/// How big the streak has grown. Each level is a bigger wave, reached on a milestone.
enum StreakTier: Int, CaseIterable, Comparable {
    case ripple, wave, tide, swell, tsunami

    init(streak: Int) {
        self = Self.allCases.last { streak >= $0.minDays } ?? .ripple
    }

    var minDays: Int {
        switch self {
        case .ripple: 0
        case .wave: 7
        case .tide: 30
        case .swell: 100
        case .tsunami: 365
        }
    }

    var title: String {
        switch self {
        case .ripple: String(localized: "Ripple")
        case .wave: String(localized: "Wave")
        case .tide: String(localized: "Tide")
        case .swell: String(localized: "Swell")
        case .tsunami: String(localized: "Tsunami")
        }
    }

    var next: StreakTier? { StreakTier(rawValue: rawValue + 1) }

    static func < (a: StreakTier, b: StreakTier) -> Bool { a.rawValue < b.rawValue }
}

/// How a missed workday was kept from breaking the streak.
enum StreakCover: String, Codable { case freeze, repair }

struct CoveredDay: Codable, Equatable {
    var day: DayKey
    var kind: StreakCover
}

/// One missed workday that can still be won back by meeting the goal before `expires` ends.
struct StreakRepairOffer: Codable, Equatable {
    var day: DayKey
    var previous: Int
    var expires: DayKey
}

/// Something Kip mentions the next time Home opens, then forgets.
enum StreakNotice: Codable, Equatable {
    case frozen(days: Int, streak: Int)
    case lost(previous: Int)
}

/// What the streak needs to remember between launches. Everything else is worked out from
/// the break history, so existing users start with the streak they've already built.
struct StreakState: Codable, Equatable {
    var freezes = 0
    var covered: [CoveredDay] = []
    /// Workdays that passed with no break and no cover. Final once recorded, so changing
    /// workdays in Settings never rewrites the past.
    var missed: [DayKey] = []
    /// The last day already checked for misses.
    var checkedThrough: DayKey?
    var best = 0
    /// Milestones reached at least once. What they gave is kept for good.
    var milestones: [Int] = []
    var energySpent = 0
    var repair: StreakRepairOffer?
    var lastRepair: DayKey?
    var notice: StreakNotice?
    var noticeDay: DayKey?

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        freezes = try c.decodeIfPresent(Int.self, forKey: .freezes) ?? 0
        covered = try c.decodeIfPresent([CoveredDay].self, forKey: .covered) ?? []
        missed = try c.decodeIfPresent([DayKey].self, forKey: .missed) ?? []
        checkedThrough = try c.decodeIfPresent(DayKey.self, forKey: .checkedThrough)
        best = try c.decodeIfPresent(Int.self, forKey: .best) ?? 0
        milestones = try c.decodeIfPresent([Int].self, forKey: .milestones) ?? []
        energySpent = try c.decodeIfPresent(Int.self, forKey: .energySpent) ?? 0
        repair = try c.decodeIfPresent(StreakRepairOffer.self, forKey: .repair)
        lastRepair = try c.decodeIfPresent(DayKey.self, forKey: .lastRepair)
        notice = try? c.decodeIfPresent(StreakNotice.self, forKey: .notice)
        noticeDay = try c.decodeIfPresent(DayKey.self, forKey: .noticeDay)
    }

    var coveredSet: Set<DayKey> { Set(covered.map(\.day)) }
    var missedSet: Set<DayKey> { Set(missed) }
}

/// What a day looks like on the streak calendar.
enum StreakDayKind: Equatable {
    case done(perfect: Bool)
    case frozen
    case repaired
    case missed
    case rest
    case pending
    case future
    case before
}

enum StreakEvent: Equatable {
    case frozen(days: Int, streak: Int)
    case lost(previous: Int)
    case repaired(streak: Int)
}

/// Pure streak logic. A streak counts days with at least one break. Only workdays can break it:
/// a day off with a break still adds to it, a day off without one is simply skipped.
struct StreakEngine {
    var active: Set<DayKey>
    var workdays: Set<Int>
    var calendar: Calendar = .current

    init(breaks: [BreakRecord], workdays: Set<Int>, calendar: Calendar = .current) {
        active = Set(breaks.map { DayKey($0.date, calendar: calendar) })
        self.workdays = workdays
        self.calendar = calendar
    }

    init(active: Set<DayKey>, workdays: Set<Int>, calendar: Calendar = .current) {
        self.active = active
        self.workdays = workdays
        self.calendar = calendar
    }

    func isWorkday(_ day: DayKey) -> Bool { workdays.contains(day.weekday(calendar)) }

    /// Whether a past day with no break and no cover ends the streak.
    private func breaksChain(_ day: DayKey, state: StreakState, missed: Set<DayKey>) -> Bool {
        if missed.contains(day) { return true }
        if let checked = state.checkedThrough, day <= checked { return false }
        return isWorkday(day)
    }

    /// The streak as of `today`. Today adds to it once it has a break; until then the streak
    /// shows the run up to yesterday.
    func current(asOf today: DayKey, state: StreakState) -> Int {
        guard let first = active.min(), first <= today else { return 0 }
        let covered = state.coveredSet, missed = state.missedSet
        if !active.contains(today) && missed.contains(today) { return 0 }
        var count = active.contains(today) ? 1 : 0
        var day = today.adding(-1, calendar: calendar)
        while day >= first {
            if active.contains(day) {
                count += 1
            } else if covered.contains(day) {
                // Kept the streak alive without adding to it.
            } else if breaksChain(day, state: state, missed: missed) {
                break
            }
            day = day.adding(-1, calendar: calendar)
        }
        return count
    }

    /// Longest streak in the history, never less than what was recorded before.
    func longest(through today: DayKey, state: StreakState) -> Int {
        guard let first = active.min() else { return state.best }
        let covered = state.coveredSet, missed = state.missedSet
        var best = state.best, run = 0
        var day = first
        while day <= today {
            if active.contains(day) {
                run += 1
            } else if covered.contains(day) || day == today {
                // Neither adds nor breaks.
            } else if breaksChain(day, state: state, missed: missed) {
                run = 0
            }
            best = max(best, run)
            day = day.adding(1, calendar: calendar)
        }
        return best
    }

    /// The streak is still alive today but needs a break before the day ends.
    func atRisk(today: DayKey, state: StreakState) -> Bool {
        !active.contains(today) && isWorkday(today) && current(asOf: today, state: state) > 0
    }

    /// Looks at every day since the last check: covers misses with shell guards when there are
    /// enough of them, otherwise records the misses, and maybe offers a repair.
    @discardableResult
    func reconcile(_ state: inout StreakState, today: DayKey) -> [StreakEvent] {
        let yesterday = today.adding(-1, calendar: calendar)
        if let offer = state.repair, offer.expires < today { state.repair = nil }
        guard let first = active.min() else {
            state.checkedThrough = max(state.checkedThrough ?? yesterday, yesterday)
            return []
        }
        let migrating = state.checkedThrough == nil
        let start = state.checkedThrough.map { $0.adding(1, calendar: calendar) } ?? first
        guard start <= yesterday else { return [] }

        let covered = state.coveredSet
        var gap: [DayKey] = []
        var day = start
        while day <= yesterday {
            if !active.contains(day) && !covered.contains(day) && isWorkday(day) { gap.append(day) }
            day = day.adding(1, calendar: calendar)
        }

        guard let firstMiss = gap.first else {
            state.checkedThrough = yesterday
            return []
        }
        if migrating {
            // First run after the update: the past is what it was, no guards to spend yet.
            state.missed += gap
            state.checkedThrough = yesterday
            state.best = longest(through: today, state: state)
            return []
        }

        var events: [StreakEvent] = []
        let previous = current(asOf: firstMiss.adding(-1, calendar: calendar), state: state)
        state.repair = nil
        if previous > 0, gap.count <= state.freezes {
            state.freezes -= gap.count
            state.covered += gap.map { CoveredDay(day: $0, kind: .freeze) }
            events.append(.frozen(days: gap.count, streak: previous))
            state.notice = .frozen(days: gap.count, streak: previous)
            state.noticeDay = today
        } else {
            state.missed += gap
            if previous > 0 {
                events.append(.lost(previous: previous))
                state.notice = .lost(previous: previous)
                state.noticeDay = today
                let cooledDown = state.lastRepair.map { $0.days(to: today, calendar: calendar) >= StreakRules.repairCooldownDays } ?? true
                if gap.count == 1, previous >= StreakRules.repairMinimum, cooledDown {
                    state.repair = StreakRepairOffer(day: firstMiss, previous: previous,
                                                     expires: max(nextWorkday(after: firstMiss), today))
                }
            }
        }
        state.checkedThrough = yesterday
        return events
    }

    /// Wins back the missed day once today's goal is met while the offer stands.
    func applyRepair(_ state: inout StreakState, today: DayKey, goalMet: Bool) -> StreakEvent? {
        guard goalMet, let offer = state.repair, today <= offer.expires else { return nil }
        state.missed.removeAll { $0 == offer.day }
        state.covered.append(CoveredDay(day: offer.day, kind: .repair))
        state.repair = nil
        state.lastRepair = today
        state.notice = nil
        return .repaired(streak: current(asOf: today, state: state))
    }

    /// Records any milestones the streak just reached. Each one gives a shell guard (while there's
    /// room) and some bring something to wear. Returns the milestones reached now, lowest first.
    func reachMilestones(_ state: inout StreakState, streak: Int) -> [Int] {
        let new = StreakRules.milestones.filter { $0 <= streak && !state.milestones.contains($0) }
        guard !new.isEmpty else { return [] }
        state.milestones += new
        state.freezes = min(StreakRules.maxFreezes, state.freezes + new.count)
        return new
    }

    func nextWorkday(after day: DayKey) -> DayKey {
        var d = day.adding(1, calendar: calendar)
        var tries = 0
        while !isWorkday(d) && tries < 7 {
            d = d.adding(1, calendar: calendar)
            tries += 1
        }
        return d
    }

    func kind(of day: DayKey, today: DayKey, state: StreakState, goalFor: (DayKey) -> Bool) -> StreakDayKind {
        if day > today { return .future }
        if active.contains(day) { return .done(perfect: goalFor(day)) }
        if let cover = state.covered.first(where: { $0.day == day }) { return cover.kind == .freeze ? .frozen : .repaired }
        if day == today { return isWorkday(day) ? .pending : .rest }
        guard let first = active.min(), day >= first else { return .before }
        return breaksChain(day, state: state, missed: state.missedSet) ? .missed : .rest
    }
}

/// What the streak did on a completed break, for the celebration screen.
struct StreakUpdate: Equatable {
    var before: Int
    var after: Int
    /// First break today, so the streak just grew.
    var extended: Bool
    var milestone: Int?
    var newWearable: Wearable?
    var freezesEarned: Int = 0
    var repaired = false
    var best: Int
    var isNewBest: Bool
    /// The last seven days ending today.
    var week: [StreakWeekDay] = []

    var shouldCelebrate: Bool { extended || repaired || milestone != nil }

    /// The level this update just climbed to, if any.
    var tierUp: StreakTier? {
        let new = StreakTier(streak: after)
        return new > StreakTier(streak: before) ? new : nil
    }
}

struct StreakWeekDay: Equatable, Identifiable {
    var day: DayKey
    var kind: StreakDayKind
    var isToday: Bool
    var id: Int { day.value }
}
