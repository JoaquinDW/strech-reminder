import SwiftUI
import UserNotifications

/// Wraps UserNotifications: permission, scheduling and the reminder's two buttons.
enum NotificationManager {
    static let categoryID = "BREAK_REMINDER"
    static let startActionID = "START_BREAK"
    static let snoozeActionID = "SNOOZE_10"
    static let snoozeMinutes: Double = 10
    static let idPrefix = "unshrimp.reminder."

    static let standCategoryID = "STAND_REMINDER"
    static let standDoneActionID = "STAND_DONE"
    static let standShowActionID = "STAND_SHOW"
    static let standSkipActionID = "STAND_SKIP"
    static let standIDPrefix = "unshrimp.reminder.stand."
    static let standMoveKey = "standMove"

    static let recapCategoryID = "WEEKLY_RECAP"
    static let recapID = "unshrimp.reminder.weekly"

    static let streakIDPrefix = "unshrimp.reminder.streak."

    /// iOS keeps at most 64 pending requests per app; leave room for the trial heads-up, the weekly
    /// recap, two streak nudges and a snooze or two.
    static let pendingLimit = 56

    static var center: UNUserNotificationCenter { .current() }

    static func registerCategories() {
        let start = UNNotificationAction(identifier: startActionID, title: String(localized: "Stretch with \(Brand.mascotName) now"),
                                         options: [.foreground], icon: UNNotificationActionIcon(systemImageName: "figure.cooldown"))
        let snooze = UNNotificationAction(identifier: snoozeActionID, title: String(localized: "In 10 minutes"),
                                          options: [], icon: UNNotificationActionIcon(systemImageName: "clock.arrow.circlepath"))
        let category = UNNotificationCategory(identifier: categoryID, actions: [start, snooze], intentIdentifiers: [], options: [])

        // A quick stand is done from the reminder itself: no unlocking, no opening the app.
        let standDone = UNNotificationAction(identifier: standDoneActionID, title: String(localized: "Done, I stood up"),
                                             options: [], icon: UNNotificationActionIcon(systemImageName: "checkmark.circle"))
        let standShow = UNNotificationAction(identifier: standShowActionID, title: String(localized: "Show me"),
                                             options: [.foreground], icon: UNNotificationActionIcon(systemImageName: "figure.stand"))
        let standSkip = UNNotificationAction(identifier: standSkipActionID, title: String(localized: "Not now"),
                                             options: [], icon: UNNotificationActionIcon(systemImageName: "moon.zzz"))
        let standCategory = UNNotificationCategory(identifier: standCategoryID, actions: [standDone, standShow, standSkip],
                                                   intentIdentifiers: [], options: [])
        let recapCategory = UNNotificationCategory(identifier: recapCategoryID, actions: [], intentIdentifiers: [], options: [])
        center.setNotificationCategories([category, standCategory, recapCategory])
    }

    static func status() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Only call after an explicit user action.
    static func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// What reschedule needs beyond preferences: recent movement and how stands have been going.
    struct History {
        var lastBreak: Date?
        var lastStand: Date?
        var standSkipStreak: Int = 0
        var hasBreaks: Bool = false
        /// Days in a row so far, and whether today already has a break.
        var streak: Int = 0
        var streakSafeToday: Bool = false
    }

    /// Replaces all pending Unshrimp reminders with a fresh plan: break reminders, quick stands
    /// between them, and the weekly recap.
    static func reschedule(preferences: Preferences, history plan: History, context: KipVoice.Context, now: Date = Date()) async {
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(idPrefix) && !$0.contains(".oneoff.") }
        center.removePendingNotificationRequests(withIdentifiers: pending)

        guard preferences.remindersEnabled else { return }
        let status = await status()
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        let schedule = preferences.schedule
        let standsOn = preferences.standsEnabled
        // With stands on there are many more reminders a day, so plan fewer days ahead. The app
        // plans again every time it opens and after every break or stand.
        let days = standsOn ? 4 : 7
        let breakDates = ReminderPlanner.upcoming(from: now, lastBreak: plan.lastBreak, schedule: schedule, days: days, limit: pendingLimit)

        var standDates: [Date] = []
        var slowedDown = false
        if standsOn {
            let lastMove = [plan.lastBreak, plan.lastStand].compactMap { $0 }.max()
            let ignored = await ignoredStandCount(since: plan.lastStand)
            slowedDown = plan.standSkipStreak + ignored >= StandRules.backoffAfter
            let notBefore = slowedDown
                ? now.addingTimeInterval(Double(preferences.standIntervalMinutes + StandRules.backoffMinutes) * 60)
                : nil
            standDates = ReminderPlanner.upcomingStands(from: now, lastMove: lastMove, schedule: schedule,
                                                        intervalMinutes: preferences.standIntervalMinutes,
                                                        notBefore: notBefore, days: days)
        }

        let portrait = await KipPortrait.file(for: context.look)
        let calendar = Calendar.current
        let all = (breakDates.map { ($0, false) } + standDates.map { ($0, true) })
            .sorted { $0.0 < $1.0 }
            .prefix(pendingLimit)
        var firstStand = true
        for (date, isStand) in all {
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request: UNNotificationRequest
            if isStand {
                let daySlots = ReminderPlanner.standSlots(on: date, schedule: schedule, intervalMinutes: preferences.standIntervalMinutes)
                let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
                let move = StandMove.pick(seed: day &* 3 &+ (daySlots.firstIndex(of: date) ?? 0))
                let content = makeContent(KipVoice.stand(move, slowedDown: slowedDown && firstStand), portrait: portrait)
                content.categoryIdentifier = standCategoryID
                content.userInfo = [standMoveKey: move.id]
                firstStand = false
                request = UNNotificationRequest(identifier: standIDPrefix + "\(Int(date.timeIntervalSince1970))", content: content, trigger: trigger)
            } else {
                let daySlots = ReminderPlanner.slots(on: date, schedule: schedule)
                let slot = KipVoice.Slot(date: date, index: daySlots.firstIndex(of: date) ?? 0, count: daySlots.count,
                                         isToday: calendar.isDate(date, inSameDayAs: now))
                let content = makeContent(KipVoice.reminder(slot: slot, context: context), portrait: portrait)
                request = UNNotificationRequest(identifier: idPrefix + "\(Int(date.timeIntervalSince1970))", content: content, trigger: trigger)
            }
            try? await center.add(request)
        }

        // The weekly recap, once there's something to recap.
        if plan.hasBreaks, let date = ReminderPlanner.weeklyRecapDate(after: now, schedule: schedule) {
            let content = makeContent(KipVoice.weeklyRecap(), portrait: portrait)
            content.categoryIdentifier = recapCategoryID
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: recapID, content: content, trigger: trigger))
        }

        // Near the end of the next workday or two without a break: one friendly nudge to keep the
        // streak going. Skipped where a break reminder already lands around the same time.
        guard plan.streak > 0 else { return }
        let recap = plan.hasBreaks ? ReminderPlanner.weeklyRecapDate(after: now, schedule: schedule) : nil
        for date in ReminderPlanner.streakSaveDates(after: now, schedule: schedule, skipToday: plan.streakSafeToday) {
            let nearby = breakDates + [recap].compactMap { $0 }
            if nearby.contains(where: { abs($0.timeIntervalSince(date)) < 30 * 60 }) { continue }
            let isToday = calendar.isDate(date, inSameDayAs: now)
            let content = makeContent(KipVoice.streakSave(streak: isToday ? plan.streak : nil, date: date), portrait: portrait)
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: streakIDPrefix + "\(Int(date.timeIntervalSince1970))",
                                                        content: content, trigger: trigger))
        }
    }

    /// Stand reminders still sitting in Notification Center since the last stand: shown, not acted on.
    /// Acting on a reminder removes it, so what's left was ignored.
    static func ignoredStandCount(since lastStand: Date?) async -> Int {
        await center.deliveredNotifications()
            .filter { $0.request.identifier.hasPrefix(standIDPrefix) && $0.date > (lastStand ?? .distantPast) }
            .count
    }

    /// Clears stand reminders from Notification Center once a stand is done or declined.
    static func clearDeliveredStands() async {
        let ids = await center.deliveredNotifications().map(\.request.identifier).filter { $0.hasPrefix(standIDPrefix) }
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    enum OneOff { case snoozed, test }

    static func scheduleOneOff(after seconds: TimeInterval, kind: OneOff, context: KipVoice.Context) async {
        let line = kind == .snoozed ? KipVoice.snoozed(context: context, seed: Int.random(in: 0..<100))
            : KipVoice.reminder(slot: .init(date: Date(), index: 1, count: 3, isToday: true), context: context)
        let content = makeContent(line, portrait: await KipPortrait.file(for: context.look))
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let request = UNNotificationRequest(identifier: idPrefix + "oneoff.\(UUID().uuidString)", content: content, trigger: trigger)
        try? await center.add(request)
    }

    private static func makeContent(_ line: KipVoice.Line, portrait: URL?) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = line.title
        content.body = line.body
        content.sound = .default
        content.categoryIdentifier = categoryID
        content.threadIdentifier = "kip"
        content.interruptionLevel = .active
        // The system moves attachment files into its own store, so every request gets its own copy.
        if let portrait {
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent("kip-\(UUID().uuidString).png")
            if (try? FileManager.default.copyItem(at: portrait, to: copy)) != nil,
               let attachment = try? UNNotificationAttachment(identifier: "kip", url: copy, options: nil) {
                content.attachments = [attachment]
            }
        }
        return content
    }
}

/// A small picture of Kip, as currently grown and dressed, for the reminder's thumbnail.
@MainActor
enum KipPortrait {
    static func file(for look: KipLook) -> URL? {
        let name = "kip-portrait-\(look.wearable?.rawValue ?? "none")-\(Int(look.uncurl * 20)).png"
        let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: url.path) { return url }
        let renderer = ImageRenderer(content: portrait(look))
        renderer.scale = 3
        guard let data = renderer.uiImage?.pngData(), (try? data.write(to: url, options: .atomic)) != nil else { return nil }
        return url
    }

    private static func portrait(_ look: KipLook) -> some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Palette.butterSoft))
            ctx.fill(Geo.circle(CGPoint(x: size.width / 2, y: size.height * 0.62), size.width * 0.42), with: .color(Palette.mintSoft))
            let pose = ShrimpMotion.pose(.inviting, t: 0, animated: false, growth: look.uncurl)
            var still = look
            still.revealAt = nil
            ShrimpRenderer.draw(pose, in: ctx, rect: CGRect(x: -6, y: 8, width: size.width + 4, height: size.height - 8), look: still)
        }
        .frame(width: 120, height: 120)
    }
}

/// Reminder copy in Kip's voice: playful, about moving together, never guilt or health claims.
/// Picks are deterministic for a given slot, so rescheduling doesn't reshuffle the words.
enum KipVoice {
    struct Line: Equatable {
        let title: String
        let body: String
    }

    struct Context {
        var minutes: Int
        var focus: Set<FocusArea>
        var look: KipLook
        var stage: Int
        var breaksToday: Int
        var goal: Int
    }

    struct Slot {
        var date: Date
        /// Position among the day's reminders, from 0.
        var index: Int
        var count: Int
        var isToday: Bool
    }

    static func reminder(slot: Slot, context c: Context, calendar: Calendar = .current) -> Line {
        let m = c.minutes
        let day = calendar.ordinality(of: .day, in: .era, for: slot.date) ?? 0
        let seed = day &* 7 &+ slot.index

        // The day's first and last nudges get their own lines.
        if slot.index == 0 {
            return pick(seed, [
                Line(title: String(localized: "Morning! I've been curled since breakfast"),
                     body: String(localized: "Uncurl with me for \(m) minutes?")),
                Line(title: String(localized: "First stretch of the day?"),
                     body: String(localized: "I already did one antenna. Join me for the other one.")),
                Line(title: String(localized: "Good morning from the desk"),
                     body: String(localized: "Let's wake up our backs. \(m) minutes, I'll lead."))
            ])
        }
        if slot.index == slot.count - 1, slot.count > 1 {
            return pick(seed, [
                Line(title: String(localized: "Last stretch of the day"),
                     body: String(localized: "One more uncurl and we can call it.")),
                Line(title: String(localized: "Wrap it up with a reach?"),
                     body: String(localized: "\(m) minutes, then the laptop can have a nap too."))
            ])
        }
        // Today's count is only known for reminders that land today.
        if slot.isToday, c.breaksToday + 1 == c.goal {
            return Line(title: String(localized: "One more and we hit our goal"),
                        body: String(localized: "I'm already stretching. \(m) minutes?"))
        }

        var lines = [
            Line(title: String(localized: "\(Brand.mascotName) looked up from the laptop"),
                 body: String(localized: "A \(m)-minute break is ready when you are.")),
            Line(title: String(localized: "My tail fell asleep"),
                 body: String(localized: "Wake it up with me? \(m) minutes, I'll count.")),
            Line(title: String(localized: "Psst. Shoulders check"),
                 body: String(localized: "Mine are up by my antennae. Roll them out with me?")),
            Line(title: String(localized: "Stretch o'clock"),
                 body: String(localized: "My antennae are tingling. \(m) minutes, then back to it.")),
            Line(title: String(localized: "Tiny break, big sigh"),
                 body: String(localized: "Stand, reach, roll. I'll go first.")),
            Line(title: String(localized: "Today's special: \(FocusArea.summary(c.focus).lowercased())"),
                 body: String(localized: "Served in \(m) minutes. I saved you a spot."))
        ]
        if (14..<18).contains(calendar.component(.hour, from: slot.date)) {
            lines.append(Line(title: String(localized: "Afternoon slump? Same"),
                              body: String(localized: "Let's shake it off together. \(m) minutes.")))
        }
        if let wearable = c.look.wearable {
            lines.append(Line(title: String(localized: "I put on my \(wearable.title.lowercased()) for this"),
                              body: String(localized: "Don't let it go to waste. \(m) minutes?")))
        }
        if c.stage >= 3 {
            lines.append(Line(title: String(localized: "Look how far I uncurl now"),
                              body: String(localized: "That's our breaks doing that. Another one?")))
        }
        return pick(seed, lines)
    }

    /// A stand reminder names the move, so it can be done without opening the app.
    static func stand(_ move: StandMove, slowedDown: Bool = false) -> Line {
        if slowedDown {
            return Line(title: String(localized: "Busy day, huh? I'll keep it short"),
                        body: String(localized: "\(move.name), \(move.seconds) seconds: \(move.cue)"))
        }
        let title: String
        switch move.id {
        case "stand-water": title = String(localized: "I'm off to refill my water. Coming?")
        case "stand-march": title = String(localized: "My legs fell asleep. March with me?")
        case "stand-reach": title = String(localized: "Stand up and reach with me")
        case "stand-backbend": title = String(localized: "I've been curled for a while. Lean back with me?")
        case "stand-sit-to-stand": title = String(localized: "Up, down, up. Five times?")
        case "stand-wall-pushup": title = String(localized: "Wall push-ups. I'll count, you push")
        case "stand-blade-squeeze": title = String(localized: "Quick posture check, standing")
        case "stand-look-far": title = String(localized: "Eyes off the screen for 20 seconds?")
        default: title = String(localized: "Quick stand with me?")
        }
        return Line(title: title, body: String(localized: "\(move.seconds) seconds: \(move.cue)"))
    }

    /// The end-of-day streak nudge. `streak` is set only when the count is sure to be right,
    /// which is for today; later days get a line without a number.
    static func streakSave(streak: Int?, date: Date, calendar: Calendar = .current) -> Line {
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        if let streak {
            return pick(day, [
                Line(title: String(localized: "\(streak) days in a row, and counting?"),
                     body: String(localized: "One quick stretch before you wrap up keeps our streak going.")),
                Line(title: String(localized: "Our \(streak)-day streak says hi"),
                     body: String(localized: "A short break before logging off? I'll lead."))
            ])
        }
        return pick(day, [
            Line(title: String(localized: "Close the day with a stretch?"),
                 body: String(localized: "A short one keeps our streak going.")),
            Line(title: String(localized: "Before the laptop naps"),
                 body: String(localized: "One stretch with me and the streak lives on."))
        ])
    }

    static func weeklyRecap() -> Line {
        Line(title: String(localized: "Your week with \(Brand.mascotName) is ready"),
             body: String(localized: "See how much we moved, and tell me how you're feeling."))
    }

    static func snoozed(context c: Context, seed: Int) -> Line {
        pick(seed, [
            Line(title: String(localized: "That was 10 minutes, right?"),
                 body: String(localized: "I waited. Patiently. Mostly. Ready now?")),
            Line(title: String(localized: "Okay, now?"),
                 body: String(localized: "No pressure. Well, a little stretch pressure. \(c.minutes) minutes.")),
            Line(title: String(localized: "I kept your spot warm"),
                 body: String(localized: "Your \(c.minutes)-minute break is still here."))
        ])
    }

    private static func pick(_ seed: Int, _ lines: [Line]) -> Line {
        lines[((seed % lines.count) + lines.count) % lines.count]
    }
}
