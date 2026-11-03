import SwiftUI
import UserNotifications

/// Wraps UserNotifications: permission, scheduling and the reminder's two buttons.
enum NotificationManager {
    static let categoryID = "BREAK_REMINDER"
    static let startActionID = "START_BREAK"
    static let snoozeActionID = "SNOOZE_10"
    static let snoozeMinutes: Double = 10
    static let idPrefix = "unshrimp.reminder."

    static var center: UNUserNotificationCenter { .current() }

    static func registerCategories() {
        let start = UNNotificationAction(identifier: startActionID, title: String(localized: "Stretch with \(Brand.mascotName) now"),
                                         options: [.foreground], icon: UNNotificationActionIcon(systemImageName: "figure.cooldown"))
        let snooze = UNNotificationAction(identifier: snoozeActionID, title: String(localized: "In 10 minutes"),
                                          options: [], icon: UNNotificationActionIcon(systemImageName: "clock.arrow.circlepath"))
        let category = UNNotificationCategory(identifier: categoryID, actions: [start, snooze], intentIdentifiers: [], options: [])
        center.setNotificationCategories([category])
    }

    static func status() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Only call after an explicit user action.
    static func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Replaces all pending Unshrimp reminders with a fresh plan.
    static func reschedule(preferences: Preferences, lastBreak: Date?, context: KipVoice.Context, now: Date = Date()) async {
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(idPrefix) && !$0.contains(".oneoff.") }
        center.removePendingNotificationRequests(withIdentifiers: pending)

        guard preferences.remindersEnabled else { return }
        let status = await status()
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        let dates = ReminderPlanner.upcoming(from: now, lastBreak: lastBreak, schedule: preferences.schedule)
        let portrait = await KipPortrait.file(for: context.look)
        let calendar = Calendar.current
        for date in dates {
            let daySlots = ReminderPlanner.slots(on: date, schedule: preferences.schedule)
            let slot = KipVoice.Slot(date: date, index: daySlots.firstIndex(of: date) ?? 0, count: daySlots.count,
                                     isToday: calendar.isDate(date, inSameDayAs: now))
            let content = makeContent(KipVoice.reminder(slot: slot, context: context), portrait: portrait)
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: idPrefix + "\(Int(date.timeIntervalSince1970))", content: content, trigger: trigger)
            try? await center.add(request)
        }
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
