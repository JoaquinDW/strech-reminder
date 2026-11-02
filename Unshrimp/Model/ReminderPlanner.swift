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
