import Foundation

/// A week of confirmed breaks, for the recap card. Minutes are the planned length of each
/// break the user confirmed, the same number the break screen promised.
struct WeeklySummary: Equatable {
    struct Day: Equatable, Identifiable {
        let date: Date
        let minutes: Int
        let breaks: Int
        let isFuture: Bool
        var id: Date { date }
    }

    let interval: DateInterval
    let days: [Day]
    let minutes: Int
    let breaks: Int
    let goalDays: Int
    /// The area that came up most, or nil with no breaks.
    let topArea: FocusArea?
    /// True when this is the current week, still in progress.
    let isCurrent: Bool

    var activeDays: Int { days.filter { $0.breaks > 0 }.count }
    var isEmpty: Bool { breaks == 0 }

    init(breaks records: [BreakRecord], weekContaining date: Date, goal: Int, now: Date = Date(), calendar: Calendar = .current) {
        let interval = calendar.dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: date, duration: 7 * 86_400)
        let inWeek = records.filter { interval.contains($0.date) }
        self.interval = interval
        isCurrent = interval.contains(now)
        days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }.map { day in
            let mine = inWeek.filter { calendar.isDate($0.date, inSameDayAs: day) }
            return Day(date: day, minutes: mine.reduce(0) { $0 + $1.minutes }, breaks: mine.count,
                       isFuture: day > now && !calendar.isDate(day, inSameDayAs: now))
        }
        minutes = inWeek.reduce(0) { $0 + $1.minutes }
        breaks = inWeek.count
        goalDays = days.filter { $0.breaks >= max(goal, 1) }.count
        let counts: [FocusArea: Int] = inWeek.reduce(into: [:]) { c, r in r.focus.forEach { c[$0, default: 0] += 1 } }
        topArea = FocusArea.allCases.filter { counts[$0] != nil }.max { (counts[$0] ?? 0) < (counts[$1] ?? 0) }
    }

    /// "Oct 27 – Nov 2"
    var rangeText: String {
        let last = interval.end.addingTimeInterval(-1)
        return (interval.start..<last).formatted(.interval.month(.abbreviated).day())
    }

    var title: String {
        isCurrent ? String(localized: "This week") : String(localized: "Last week")
    }

    /// What Kip says on the card. About showing up, never about results for the body.
    var kipLine: String {
        if activeDays >= 5 { return String(localized: "Stretches nearly every day. I'm practically a straight line.") }
        if goalDays >= 3 { return String(localized: "Goal after goal. My antennae are doing a little dance.") }
        if activeDays >= 3 { return String(localized: "We kept showing up. That's the whole trick.") }
        if breaks >= 2 { return String(localized: "A few breaks in. I like this rhythm.") }
        return String(localized: "One break is a start. I'll save you a spot at the desk.")
    }
}

extension AppModel {
    /// The week to recap: this one once it has a break, otherwise last week if that had any.
    func weeklySummary(_ now: Date = Date()) -> WeeklySummary? {
        let current = WeeklySummary(breaks: data.breaks, weekContaining: now, goal: prefs.dailyGoal, now: now)
        if !current.isEmpty { return current }
        guard let lastWeek = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: now) else { return nil }
        let previous = WeeklySummary(breaks: data.breaks, weekContaining: lastWeek, goal: prefs.dailyGoal, now: now)
        return previous.isEmpty ? nil : previous
    }
}
