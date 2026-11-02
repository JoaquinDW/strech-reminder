import SwiftUI
import Observation
import UserNotifications

/// JSON file persistence in Application Support.
struct Store {
    private var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("unshrimp-data.json")
    }

    func load() -> AppData? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(AppData.self, from: data)
    }

    func save(_ value: AppData) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(value)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Unshrimp: failed to save data: \(error)")
        }
    }

    func delete() { try? FileManager.default.removeItem(at: url) }
}

struct DaySummary: Identifiable {
    let date: Date
    let count: Int
    let goalMet: Bool
    let isToday: Bool
    let isWorkday: Bool
    let isFuture: Bool
    var id: Date { date }
}

@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    private(set) var data: AppData
    var notificationStatus: UNAuthorizationStatus = .notDetermined
    /// Set when the user taps a reminder; Home opens a break.
    var breakRequestedFromNotification = false
    /// Item to pop into the desk scene when Home appears after an unlock.
    var celebrateItem: DeskItem?
    var celebrateStart: Double = 0

    private let store = Store()
    private let calendar = Calendar.current

    init() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-resetData") { store.delete() }
        data = store.load() ?? AppData()
        if args.contains("-seedWeek") { seedWeek() }
    }

    // MARK: Preferences

    var prefs: Preferences { data.preferences }

    func updatePrefs(_ change: (inout Preferences) -> Void) {
        var p = data.preferences
        change(&p)
        guard p != data.preferences else { return }
        data.preferences = p
        save()
        Task { await rescheduleReminders() }
    }

    func finishOnboarding(with prefs: Preferences) {
        data.preferences = prefs
        data.hasOnboarded = true
        save()
        Task { await rescheduleReminders() }
    }

    func replayOnboarding() {
        data.hasOnboarded = false
        save()
    }

    func resetEverything() {
        data = AppData()
        save()
        Task { await rescheduleReminders() }
    }

    // MARK: Derived state

    var unlocked: Set<DeskItem> { Set(data.unlocked) }
    var nextItem: DeskItem? { DeskItem.allCases.first { !unlocked.contains($0) } }
    var lastBreak: Date? { data.breaks.map(\.date).max() }
    var isFirstDay: Bool { data.breaks.isEmpty }

    func breaksToday(_ now: Date = Date()) -> Int {
        data.breaks.filter { calendar.isDate($0.date, inSameDayAs: now) }.count
    }

    func goalMet(_ now: Date = Date()) -> Bool { breaksToday(now) >= prefs.dailyGoal }

    func daysAway(_ now: Date = Date()) -> Int {
        guard let last = lastBreak else { return 0 }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: calendar.startOfDay(for: now)).day ?? 0
    }

    var weekDates: [Date] {
        let now = Date()
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    func week(_ now: Date = Date()) -> [DaySummary] {
        weekDates.map { day in
            let count = data.breaks.filter { calendar.isDate($0.date, inSameDayAs: day) }.count
            return DaySummary(
                date: day, count: count, goalMet: count >= prefs.dailyGoal,
                isToday: calendar.isDate(day, inSameDayAs: now),
                isWorkday: prefs.schedule.workdays.contains(calendar.component(.weekday, from: day)),
                isFuture: day > now && !calendar.isDate(day, inSameDayAs: now)
            )
        }
    }

    /// 0…5 stops reached on this week's adventure.
    func adventureStops(_ now: Date = Date()) -> Int {
        min(Adventure.stops.count, week(now).filter(\.goalMet).count)
    }

    func nextReminder(_ now: Date = Date()) -> Date? {
        guard prefs.remindersEnabled else { return nil }
        return ReminderPlanner.upcoming(from: now, lastBreak: lastBreak, schedule: prefs.schedule, limit: 1).first
    }

    var remindersBlocked: Bool { notificationStatus == .denied }
    var notificationsAllowed: Bool {
        notificationStatus == .authorized || notificationStatus == .provisional || notificationStatus == .ephemeral
    }

    func isBreakDue(_ now: Date = Date()) -> Bool {
        guard !goalMet(now) else { return false }
        guard let last = lastBreak, calendar.isDate(last, inSameDayAs: now) else { return true }
        return now.timeIntervalSince(last) >= Double(prefs.schedule.intervalMinutes) * 60
    }

    func shrimpState(_ now: Date = Date()) -> ShrimpState {
        if goalMet(now) { return .resting }
        return isBreakDue(now) ? .inviting : .working
    }

    func greeting(_ now: Date = Date()) -> String {
        switch calendar.component(.hour, from: now) {
        case 5..<12: String(localized: "Good morning")
        case 12..<17: String(localized: "Good afternoon")
        case 17..<22: String(localized: "Good evening")
        default: String(localized: "Hello, night owl")
        }
    }

    /// What Kip says on Home. Friendly, never guilt-trippy.
    func speech(_ now: Date = Date()) -> String {
        let today = breaksToday(now)
        if isFirstDay { return String(localized: "First break together? I'll stretch too.") }
        if today == 0 && daysAway(now) >= EnergyRules.absenceDays {
            return String(localized: "Hey, you're back! I kept your desk warm.")
        }
        if goalMet(now) { return String(localized: "Goal done. I'm just going to sit here and feel nice.") }
        if !ReminderPlanner.isWithinWorkHours(now, schedule: prefs.schedule) && today == 0 {
            return String(localized: "Off the clock? A stretch still counts.")
        }
        if isBreakDue(now) {
            return today == 0
                ? String(localized: "I've been typing for ages. Break with me?")
                : String(localized: "My antennae say it's stretch time.")
        }
        return String(localized: "Back to it. I'll wave when it's time.")
    }

    // MARK: Breaks and rewards

    @discardableResult
    func recordBreak(minutes: Int, focus: Set<FocusArea>, at date: Date = Date()) -> BreakResult {
        let before = data.energy
        let todayBefore = breaksToday(date)
        let stopsBefore = adventureStops(date)
        let lines = EnergyRules.award(at: date, history: data.breaks, breaksTodayBefore: todayBefore, goal: prefs.dailyGoal)
        let earned = lines.reduce(0) { $0 + $1.amount }
        data.breaks.append(BreakRecord(date: date, minutes: minutes, focus: FocusArea.allCases.filter { focus.contains($0) }, energy: earned))
        data.energy += earned
        let newItems = DeskItem.allCases.filter { !data.unlocked.contains($0) && $0.cost <= data.energy }
        data.unlocked.append(contentsOf: newItems)
        save()
        if let first = newItems.first {
            celebrateItem = first
        }
        Task { await rescheduleReminders() }
        let stopsAfter = adventureStops(date)
        return BreakResult(
            lines: lines, energyBefore: before, energyAfter: data.energy, newlyUnlocked: newItems,
            breaksToday: todayBefore + 1, goal: prefs.dailyGoal,
            reachedGoalNow: todayBefore + 1 == prefs.dailyGoal,
            adventureStop: stopsAfter > stopsBefore ? stopsAfter : 0
        )
    }

    /// Progress toward `item` as (current, needed) relative to the previous unlock.
    func progress(toward item: DeskItem) -> (current: Int, needed: Int) {
        let prevCost = DeskItem.allCases.last { $0.cost < item.cost }?.cost ?? 0
        return (max(0, data.energy - prevCost), item.cost - prevCost)
    }

    // MARK: Notifications

    func refreshNotificationStatus() async {
        notificationStatus = await NotificationManager.status()
    }

    @discardableResult
    func requestNotifications() async -> Bool {
        let granted = await NotificationManager.requestPermission()
        await refreshNotificationStatus()
        if granted, !prefs.remindersEnabled { updatePrefs { $0.remindersEnabled = true } }
        await rescheduleReminders()
        return granted
    }

    func rescheduleReminders() async {
        await NotificationManager.reschedule(preferences: prefs, lastBreak: lastBreak)
    }

    func snooze() async {
        await NotificationManager.scheduleOneOff(after: 15 * 60, minutes: prefs.breakLength.minutes)
    }

    func sendTestReminder() async {
        await NotificationManager.scheduleOneOff(after: 5, minutes: prefs.breakLength.minutes)
    }

    // MARK: Private

    private func save() { store.save(data) }

    /// Debug: fills earlier days of this week with sample breaks (launch argument -seedWeek).
    private func seedWeek() {
        guard data.breaks.isEmpty else { return }
        data.hasOnboarded = true
        let now = Date()
        for day in weekDates where day < calendar.startOfDay(for: now) {
            let n = [2, 3, 3, 1, 3][calendar.component(.weekday, from: day) % 5]
            for i in 0..<n {
                let d = calendar.date(bySettingHour: 10 + i * 2, minute: 15, second: 0, of: day) ?? day
                recordBreak(minutes: 3, focus: [.neck, .shoulders], at: d)
            }
        }
        celebrateItem = nil
    }
}
