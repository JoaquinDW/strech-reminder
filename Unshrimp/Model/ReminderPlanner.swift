import Foundation

/// Pure scheduling logic for reminders, kept separate from UserNotifications so it can
/// drive both the real notifications and the "next nudge" label.
enum ReminderPlanner {
    /// Reminder times on a given day: every interval after the start of work, before the end.
    static func slots(on day: Date, schedule: WorkSchedule, calendar: Calendar = .current) -> [Date] {
        let weekday = calendar.component(.weekday, from: day)
        guard schedule.workdays.contains(weekday), schedule.endMinute > schedule.startMinute, schedule.intervalMinutes > 0 else { return [] }
        let start = calendar.startOfDay(for: day)
        var result: [Date] = []
        var minute = schedule.startMinute + schedule.intervalMinutes
        while minute < schedule.endMinute {
            if let d = calendar.date(byAdding: .minute, value: minute, to: start) { result.append(d) }
            minute += schedule.intervalMinutes
        }
        return result
    }

    static func nudgesPerDay(_ schedule: WorkSchedule) -> Int {
        guard schedule.endMinute > schedule.startMinute, schedule.intervalMinutes > 0 else { return 0 }
        return max(0, (schedule.endMinute - schedule.startMinute - 1) / schedule.intervalMinutes)
    }

    /// Upcoming reminders, skipping any that would land soon after a break you already took.
    static func upcoming(from now: Date, lastBreak: Date?, schedule: WorkSchedule, days: Int = 7, limit: Int = 60, calendar: Calendar = .current) -> [Date] {
        var result: [Date] = []
        let quiet = Double(schedule.intervalMinutes) * 60 * 0.6
        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
            for slot in slots(on: day, schedule: schedule, calendar: calendar) where slot > now {
                if let lastBreak, slot > lastBreak, slot.timeIntervalSince(lastBreak) < quiet { continue }
                result.append(slot)
                if result.count >= limit { return result }
            }
        }
        return result
    }

    // MARK: Quick stands

    /// Stand reminder times on a day: every stand interval from the start of work, before the end,
    /// leaving room around break reminders so the two never pile up.
    static func standSlots(on day: Date, schedule: WorkSchedule, intervalMinutes: Int, calendar: Calendar = .current) -> [Date] {
        guard intervalMinutes > 0 else { return [] }
        let breaks = slots(on: day, schedule: schedule, calendar: calendar)
        let weekday = calendar.component(.weekday, from: day)
        guard schedule.workdays.contains(weekday), schedule.endMinute > schedule.startMinute else { return [] }
        let start = calendar.startOfDay(for: day)
        let gap = Double(StandRules.gapAroundBreakMinutes) * 60
        var result: [Date] = []
        var minute = schedule.startMinute + intervalMinutes
        while minute < schedule.endMinute {
            if let d = calendar.date(byAdding: .minute, value: minute, to: start),
               !breaks.contains(where: { abs($0.timeIntervalSince(d)) <= gap }) {
                result.append(d)
            }
            minute += intervalMinutes
        }
        return result
    }

    static func standsPerDay(_ schedule: WorkSchedule, intervalMinutes: Int) -> Int {
        let day = Calendar.current.startOfDay(for: Date())
        var plain = schedule
        plain.workdays = Set(1...7)
        return standSlots(on: day, schedule: plain, intervalMinutes: intervalMinutes).count
    }

    /// Upcoming stand reminders. Skips any that land soon after the last movement (a break or a
    /// stand), and any before `notBefore`, which is how the rhythm slows after ignored reminders.
    static func upcomingStands(from now: Date, lastMove: Date?, schedule: WorkSchedule, intervalMinutes: Int,
                               notBefore: Date? = nil, days: Int = 4, calendar: Calendar = .current) -> [Date] {
        var result: [Date] = []
        let quiet = Double(intervalMinutes) * 60 * 0.6
        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
            for slot in standSlots(on: day, schedule: schedule, intervalMinutes: intervalMinutes, calendar: calendar) where slot > now {
                if let lastMove, slot > lastMove, slot.timeIntervalSince(lastMove) < quiet { continue }
                if let notBefore, slot < notBefore { continue }
                result.append(slot)
            }
        }
        return result
    }

    /// When the weekly recap reminder goes out: an hour before the end of the last workday of the
    /// week containing `now`, or next week's if that has passed.
    static func weeklyRecapDate(after now: Date, schedule: WorkSchedule, calendar: Calendar = .current) -> Date? {
        guard !schedule.workdays.isEmpty else { return nil }
        for weekOffset in 0..<2 {
            guard let anchor = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: now),
                  let week = calendar.dateInterval(of: .weekOfYear, for: anchor) else { continue }
            let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: week.start) }
                .filter { schedule.workdays.contains(calendar.component(.weekday, from: $0)) }
            guard let last = days.last else { continue }
            let minute = max(schedule.startMinute, schedule.endMinute - 60)
            if let date = calendar.date(byAdding: .minute, value: minute, to: calendar.startOfDay(for: last)), date > now {
                return date
            }
        }
        return nil
    }

    static func isWithinWorkHours(_ date: Date, schedule: WorkSchedule, calendar: Calendar = .current) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        guard schedule.workdays.contains(weekday) else { return false }
        let c = calendar.dateComponents([.hour, .minute], from: date)
        let m = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        return m >= schedule.startMinute && m < schedule.endMinute
    }

    /// "at 2:30 PM", "tomorrow at 9:00 AM", "Mon at 10:30 AM"
    static func describe(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDate(date, inSameDayAs: now) { return String(localized: "today at \(time)") }
        if calendar.isDateInTomorrow(date) { return String(localized: "tomorrow at \(time)") }
        let day = date.formatted(.dateTime.weekday(.abbreviated))
        return String(localized: "\(day) at \(time)")
    }
}
