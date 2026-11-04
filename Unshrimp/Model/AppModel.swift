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
        if let i = args.firstIndex(of: "-seedStreak"), args.indices.contains(i + 1), let n = Int(args[i + 1]) { seedStreak(n) }
        #endif
        reconcileStreak()
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

    /// Everything Kip has earned to wear: growth stages first, then streak milestones.
    var ownedWearables: [Wearable] {
        growth.wearables + Wearable.allCases.filter { w in w.streakMilestone.map { data.streak.milestones.contains($0) } ?? false }
    }

    /// Puts on (or takes off, with nil) one of the wearables Kip has earned.
    func wear(_ wearable: Wearable?) {
        guard wearable == nil || ownedWearables.contains(wearable!) else { return }
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
        if today == 0, let notice = streakNotice(now) {
            switch notice {
            case .frozen(let days, let streak):
                return days == 1
                    ? String(localized: "I used a shell guard. Our \(streak)-day streak is safe.")
                    : String(localized: "I used \(days) shell guards. Our \(streak)-day streak is safe.")
            case .lost(let previous):
                if let offer = repairOffer(now) {
                    return String(localized: "Hit today's goal and we win back our \(offer.previous)-day streak.")
                }
                return String(localized: "Our streak starts fresh, but I remember all \(previous) days. Let's go again?")
            }
        }
        if today == 0 && daysAway(now) >= EnergyRules.absenceDays {
            return String(localized: "Hey, you're back! I kept your desk warm.")
        }
        if goalMet(now) { return String(localized: "Goal done. I'm just going to sit here and feel nice.") }
        if !ReminderPlanner.isWithinWorkHours(now, schedule: prefs.schedule) && today == 0 {
            return String(localized: "Off the clock? A stretch still counts.")
        }
        if isBreakDue(now) {
            let run = streak(now)
            if today == 0, run >= 2, streakAtRisk(now) {
                return String(localized: "One stretch makes it \(run + 1) days in a row. Break with me?")
            }
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
        reconcileStreak(date)
        let streakBefore = streak(date)
        let bestBefore = bestStreak(date)
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
        let streakUpdate = updateStreak(at: date, before: streakBefore, bestBefore: bestBefore,
                                        firstToday: todayBefore == 0, goalMet: todayBefore + 1 >= prefs.dailyGoal)
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
            feel: feel,
            streak: streakUpdate
        )
    }

    // MARK: Streak

    private var streakEngine: StreakEngine {
        StreakEngine(breaks: data.breaks, workdays: prefs.schedule.workdays, calendar: calendar)
    }

    func day(_ date: Date = Date()) -> DayKey { DayKey(date, calendar: calendar) }

    /// Days in a row with a break. Until today's first break it shows the run up to yesterday.
    func streak(_ now: Date = Date()) -> Int { streakEngine.current(asOf: day(now), state: data.streak) }

    func bestStreak(_ now: Date = Date()) -> Int { max(data.streak.best, streak(now)) }

    /// Today has a break, so the streak is safe until tomorrow.
    func streakSafeToday(_ now: Date = Date()) -> Bool { breaksToday(now) > 0 }

    /// A workday with a streak going and no break yet.
    func streakAtRisk(_ now: Date = Date()) -> Bool { streakEngine.atRisk(today: day(now), state: data.streak) }

    var streakFreezes: Int { data.streak.freezes }

    /// Energy that can go on shell guards. Spending it never takes anything off the desk.
    var spendableEnergy: Int { max(0, data.energy - data.streak.energySpent) }

    var canBuyFreeze: Bool { data.streak.freezes < StreakRules.maxFreezes && spendableEnergy >= StreakRules.freezeCost }

    func buyFreeze() {
        guard canBuyFreeze else { return }
        data.streak.energySpent += StreakRules.freezeCost
        data.streak.freezes += 1
        save()
        Analytics.capture("streak_freeze_bought", properties: ["freezes": data.streak.freezes, "streak": streak()])
    }

    func repairOffer(_ now: Date = Date()) -> StreakRepairOffer? {
        guard let offer = data.streak.repair, day(now) <= offer.expires else { return nil }
        return offer
    }

    /// Something to mention today, until the first break.
    func streakNotice(_ now: Date = Date()) -> StreakNotice? {
        guard data.streak.noticeDay == day(now) else { return nil }
        return data.streak.notice
    }

    /// Checks the days since the last look: spends shell guards on missed workdays, or records the miss.
    func reconcileStreak(_ now: Date = Date()) {
        let before = data.streak
        var state = data.streak
        let engine = streakEngine
        let events = engine.reconcile(&state, today: day(now))
        state.best = engine.longest(through: day(now), state: state)
        guard state != before else { return }
        data.streak = state
        save()
        for event in events {
            switch event {
            case .frozen(let days, let streak):
                Analytics.capture("streak_freeze_used", properties: ["days": days, "streak": streak, "freezes_left": state.freezes])
            case .lost(let previous):
                Analytics.capture("streak_lost", properties: ["previous": previous, "repair_offered": state.repair != nil])
            case .repaired:
                break
            }
        }
    }

    /// The streak calendar for the month containing `date`, padded to whole weeks.
    func streakMonth(_ date: Date, now: Date = Date()) -> [StreakWeekDay?] {
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return [] }
        let first = day(interval.start)
        let lead = (first.weekday(calendar) - calendar.firstWeekday + 7) % 7
        let count = calendar.range(of: .day, in: .month, for: date)?.count ?? 30
        return Array(repeating: nil, count: lead) + (0..<count).map { streakDay(first.adding($0, calendar: calendar), now: now) }
    }

    func streakWeek(_ now: Date = Date()) -> [StreakWeekDay] {
        let today = day(now)
        return (0..<7).reversed().map { streakDay(today.adding(-$0, calendar: calendar), now: now) }
    }

    private func streakDay(_ d: DayKey, now: Date) -> StreakWeekDay {
        let today = day(now)
        let engine = streakEngine
        let kind = engine.kind(of: d, today: today, state: data.streak) { key in
            data.breaks.filter { DayKey($0.date, calendar: calendar) == key }.count >= prefs.dailyGoal
        }
        return StreakWeekDay(day: d, kind: kind, isToday: d == today)
    }

    /// After a break is saved: repairs, milestones and what to celebrate.
    private func updateStreak(at date: Date, before: Int, bestBefore: Int, firstToday: Bool, goalMet: Bool) -> StreakUpdate {
        let engine = streakEngine
        let today = day(date)
        var state = data.streak
        let repaired = engine.applyRepair(&state, today: today, goalMet: goalMet) != nil
        let after = engine.current(asOf: today, state: state)
        let freezesBefore = state.freezes
        let reached = engine.reachMilestones(&state, streak: after)
        state.best = max(engine.longest(through: today, state: state), after)
        let wearable = reached.compactMap(StreakRules.wearable(forMilestone:)).last
        data.streak = state
        if let wearable { data.outfit = wearable }

        let milestone = reached.last
        if firstToday {
            Analytics.capture("streak_extended", properties: ["streak": after, "is_milestone": milestone != nil])
        }
        if repaired { Analytics.capture("streak_repaired", properties: ["streak": after]) }
        for m in reached { Analytics.capture("streak_milestone", properties: ["days": m]) }

        let weekDays = streakWeek(date)
        return StreakUpdate(before: before, after: after, extended: firstToday && after > before,
                            milestone: milestone, newWearable: wearable,
                            freezesEarned: state.freezes - freezesBefore, repaired: repaired,
                            best: state.best, isNewBest: after > bestBefore && bestBefore >= StreakRules.milestones[0],
                            week: weekDays)
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
                                            standSkipStreak: data.standSkipStreak, hasBreaks: !data.breaks.isEmpty,
                                            streak: streak(), streakSafeToday: streakSafeToday())
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

    /// Debug: one break a day for the `days` days before today, so the next break extends the
    /// streak (-seedStreak 6 lands on the 7-day milestone).
    private func seedStreak(_ days: Int) {
        guard data.breaks.isEmpty else { return }
        data.hasOnboarded = true
        let now = Date()
        for offset in stride(from: max(0, days), to: 0, by: -1) {
            guard let d = calendar.date(byAdding: .day, value: -offset, to: now),
                  let at = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: d) else { continue }
            data.breaks.append(BreakRecord(date: at, minutes: 3, focus: [.neck], energy: EnergyRules.base))
            data.energy += EnergyRules.base
        }
        data.streak = StreakState()
        data.streak.checkedThrough = day(now).adding(-1, calendar: calendar)
        data.streak.milestones = StreakRules.milestones.filter { $0 < days }
        save()
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
