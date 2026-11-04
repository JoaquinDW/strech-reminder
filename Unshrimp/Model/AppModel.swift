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
            let failure = error as NSError
            Analytics.capture("app_error", properties: ["operation": "save_progress", "error_domain": failure.domain, "error_code": failure.code])
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
    /// The reminder's "Start" button skips the overview and goes straight into the first move.
    var skipBreakIntro = false
    /// Set when a stand reminder's "Show me" is tapped; Home opens that one move.
    var standRequested: String?
    /// Set when the weekly recap reminder is tapped; Home opens the recap.
    var recapRequested = false
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
        #if DEBUG
        if let i = args.firstIndex(of: "-seedGrowth"), args.indices.contains(i + 1), let n = Int(args[i + 1]) { seedGrowth(n) }
        if args.contains("-testReminder") { Task { await sendTestReminder() } }
        if args.contains("-testStartFromNotification") {
            breakRequestedFromNotification = true
            skipBreakIntro = true
        }
        if args.contains("-testStand") { standRequested = StandMove.all[0].id }
        #endif
    }

    // MARK: Preferences

    var prefs: Preferences { data.preferences }

    func updatePrefs(_ change: (inout Preferences) -> Void) {
        var p = data.preferences
        change(&p)
        guard p != data.preferences else { return }
        if p.remindersEnabled != data.preferences.remindersEnabled {
            Analytics.capture("reminders_toggled", properties: ["enabled": p.remindersEnabled])
        }
        if p.standsEnabled != data.preferences.standsEnabled {
            Analytics.capture("stands_toggled", properties: ["enabled": p.standsEnabled])
        }
        data.preferences = p
        save()
        Task { await rescheduleReminders() }
    }

    func finishOnboarding(with prefs: Preferences, baseline: [FocusArea: Int] = [:]) {
        guard !data.hasOnboarded else { return }
        data.preferences = prefs
        data.hasOnboarded = true
        let now = Date()
        // Only the areas the user actually rated; an untouched slider isn't an answer.
        let scores = baseline.filter { prefs.focusAreas.contains($0.key) }
        data.stiffness += scores.map { StiffnessRecord(date: now, area: $0.key, score: $0.value) }
        if !scores.isEmpty { data.lastStiffnessPrompt = now }
        save()
        Analytics.capture("onboarding_completed", properties: [
            "duration_minutes": prefs.breakLength.minutes,
            "daily_goal": prefs.dailyGoal,
            "reminders_enabled": prefs.remindersEnabled && notificationsAllowed,
            "stands_enabled": prefs.standsEnabled,
            "stand_interval_minutes": prefs.standIntervalMinutes,
            "stiffness_baseline_given": !scores.isEmpty
        ])
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
    var growth: KipGrowth { KipGrowth(breaks: data.breaks.count) }
    var look: KipLook { KipLook(uncurl: growth.uncurl, wearable: data.outfit) }

    /// Puts on (or takes off, with nil) one of the wearables Kip has earned.
    func wear(_ wearable: Wearable?) {
        guard wearable == nil || growth.wearables.contains(wearable!) else { return }
        data.outfit = wearable
        save()
        Task { await rescheduleReminders() }
    }
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

    /// The next break's routine. Moves it shows count as done, so the following break rotates on.
    func nextRoutine() -> Routine {
        let routine = DemoLibrary.routine(length: prefs.breakLength, focus: prefs.focusAreas, recent: data.recentMoves,
                                          avoid: avoidedMoveIDs())
        data.recentMoves = Array((data.recentMoves + routine.moves.map(\.id)).suffix(DemoLibrary.historyLimit))
        save()
        return routine
    }

    @discardableResult
    func recordBreak(minutes: Int, focus: Set<FocusArea>, feel: BreakFeel? = nil, at date: Date = Date()) -> BreakResult {
        let before = data.energy
        let todayBefore = breaksToday(date)
        let stopsBefore = adventureStops(date)
        let stageBefore = growth.stageIndex
        let lines = EnergyRules.award(at: date, history: data.breaks, breaksTodayBefore: todayBefore, goal: prefs.dailyGoal)
        let earned = lines.reduce(0) { $0 + $1.amount }
        data.breaks.append(BreakRecord(date: date, minutes: minutes, focus: FocusArea.allCases.filter { focus.contains($0) }, energy: earned, feel: feel))
        data.energy += earned
        let newItems = DeskItem.allCases.filter { !data.unlocked.contains($0) && $0.cost <= data.energy }
        data.unlocked.append(contentsOf: newItems)
        let stageAfter = growth.stageIndex
        let newWearable = stageAfter > stageBefore ? KipGrowth.stages[stageAfter].wearable : nil
        if let newWearable { data.outfit = newWearable }
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
            adventureStop: stopsAfter > stopsBefore ? stopsAfter : 0,
            newStage: stageAfter > stageBefore ? stageAfter : nil,
            newWearable: newWearable,
            feel: feel
        )
    }

    // MARK: Quick stands

    func standsToday(_ now: Date = Date()) -> Int {
        data.stands.filter { calendar.isDate($0.date, inSameDayAs: now) }.count
    }

    var lastStand: Date? { data.stands.map(\.date).max() }

    /// Records a quick stand. Returns the energy it earned (capped per day).
    @discardableResult
    func recordStand(moveID: String, source: StandSource, at date: Date = Date()) async -> Int {
        let todayEnergy = data.stands.filter { calendar.isDate($0.date, inSameDayAs: date) }.reduce(0) { $0 + $1.energy }
        let earned = StandRules.energy(standsTodayEnergy: todayEnergy)
        data.stands.append(StandRecord(date: date, moveID: moveID, energy: earned))
        data.standSkipStreak = 0
        data.energy += earned
        let newItems = DeskItem.allCases.filter { !data.unlocked.contains($0) && $0.cost <= data.energy }
        data.unlocked.append(contentsOf: newItems)
        if let first = newItems.first { celebrateItem = first }
        save()
        Analytics.capture("stand_completed", properties: ["move_id": moveID, "source": source.rawValue,
                                                          "stands_today": standsToday(date)])
        await NotificationManager.clearDeliveredStands()
        await rescheduleReminders()
        return earned
    }

    func skipStand(moveID: String?) async {
        data.standSkipStreak += 1
        save()
        Analytics.capture("stand_skipped", properties: ["move_id": moveID ?? "", "skip_streak": data.standSkipStreak])
        await NotificationManager.clearDeliveredStands()
        await rescheduleReminders()
    }

    // MARK: How it feels

    /// Leaves a move out of routines for a while after the user said it bothered them.
    func avoid(moveID: String, at date: Date = Date()) {
        data.avoidedMoves[moveID] = date
        save()
        Analytics.capture("move_avoided", properties: ["move_id": moveID])
    }

    func avoidedMoveIDs(_ now: Date = Date()) -> Set<String> {
        let limit = Double(StandRules.avoidDays) * 86_400
        return Set(data.avoidedMoves.filter { now.timeIntervalSince($0.value) < limit }.keys)
    }

    /// The weekly "how stiff are you?" card shows once a week, after the first break.
    func stiffnessCheckinDue(_ now: Date = Date()) -> Bool {
        guard data.hasOnboarded, !data.breaks.isEmpty else { return false }
        guard let last = data.lastStiffnessPrompt else { return true }
        return now.timeIntervalSince(last) >= Double(StandRules.checkinDays) * 86_400
    }

    func recordStiffness(_ scores: [FocusArea: Int], at date: Date = Date()) {
        data.stiffness += scores.sorted { $0.key.rawValue < $1.key.rawValue }
            .map { StiffnessRecord(date: date, area: $0.key, score: $0.value) }
        data.lastStiffnessPrompt = date
        save()
        if !scores.isEmpty {
            let average = Double(scores.values.reduce(0, +)) / Double(scores.count)
            Analytics.capture("stiffness_checkin", properties: ["areas_count": scores.count,
                                                                "average_score": (average * 10).rounded() / 10])
        }
    }

    func skipStiffnessCheckin(at date: Date = Date()) {
        data.lastStiffnessPrompt = date
        save()
        Analytics.capture("stiffness_checkin_skipped")
    }

    var stiffnessTrends: [StiffnessTrend] { StiffnessTrend.trends(data.stiffness) }

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
        let previousStatus = await NotificationManager.status()
        if previousStatus == .notDetermined { Analytics.capture("notification_permission_requested") }
        let granted = await NotificationManager.requestPermission()
        await refreshNotificationStatus()
        if previousStatus == .notDetermined {
            Analytics.capture("notification_permission_result", properties: ["granted": granted])
        }
        if granted, !prefs.remindersEnabled { updatePrefs { $0.remindersEnabled = true } }
        await rescheduleReminders()
        return granted
    }

    func rescheduleReminders() async {
        // Without a subscription Kip stays quiet: a reminder would only lead to the paywall.
        var preferences = prefs
        if !Subscription.shared.isActive { preferences.remindersEnabled = false }
        let plan = NotificationManager.History(lastBreak: lastBreak, lastStand: lastStand,
                                            standSkipStreak: data.standSkipStreak, hasBreaks: !data.breaks.isEmpty)
        await NotificationManager.reschedule(preferences: preferences, history: plan, context: voiceContext)
    }

    func snooze() async {
        await NotificationManager.scheduleOneOff(after: NotificationManager.snoozeMinutes * 60, kind: .snoozed, context: voiceContext)
    }

    func sendTestReminder() async {
        await NotificationManager.scheduleOneOff(after: 5, kind: .test, context: voiceContext)
    }

    private var voiceContext: KipVoice.Context {
        KipVoice.Context(minutes: prefs.breakLength.minutes, focus: prefs.focusAreas, look: look,
                         stage: growth.stageIndex, breaksToday: breaksToday(), goal: prefs.dailyGoal)
    }

    // MARK: Private

    private func save() { store.save(data) }

    /// Debug: adds `count` breaks spread over the past weeks so Kip's growth can be previewed.
    private func seedGrowth(_ count: Int) {
        data.hasOnboarded = true
        let now = Date()
        for i in 0..<max(0, count) {
            let day = calendar.date(byAdding: .day, value: -(count - i) / 3 - 1, to: now) ?? now
            let d = calendar.date(bySettingHour: 10 + (i % 3) * 2, minute: 30, second: 0, of: day) ?? day
            recordBreak(minutes: 3, focus: [.neck, .shoulders], at: d)
        }
        // One just now, so Home shows Kip back at work.
        if count > 0 { recordBreak(minutes: 3, focus: [.neck], at: now.addingTimeInterval(-600)) }
        celebrateItem = nil
    }

    /// Debug: fills earlier days of this week with sample breaks (launch argument -seedWeek).
    private func seedWeek() {
        guard data.breaks.isEmpty else { return }
        data.hasOnboarded = true
        let now = Date()
        let pastDays = (1...6).compactMap { calendar.date(byAdding: .day, value: -$0, to: calendar.startOfDay(for: now)) }.reversed()
        for day in pastDays {
            let n = [2, 3, 3, 1, 3][calendar.component(.weekday, from: day) % 5]
            for i in 0..<n {
                let d = calendar.date(bySettingHour: 10 + i * 2, minute: 15, second: 0, of: day) ?? day
                recordBreak(minutes: 3, focus: [.neck, .shoulders], at: d)
            }
        }
        if let morning = calendar.date(bySettingHour: 9, minute: 40, second: 0, of: now), morning < now {
            recordBreak(minutes: 3, focus: [.neck, .shoulders], at: morning)
        }
        celebrateItem = nil
    }
}
