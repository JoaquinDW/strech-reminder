import Foundation
import UserNotifications

/// Wraps UserNotifications: permission, scheduling and the "Start a break" action.
enum NotificationManager {
    static let categoryID = "BREAK_REMINDER"
    static let startActionID = "START_BREAK"
    static let snoozeActionID = "SNOOZE_15"
    static let idPrefix = "unshrimp.reminder."

    static var center: UNUserNotificationCenter { .current() }

    static func registerCategories() {
        let start = UNNotificationAction(identifier: startActionID, title: String(localized: "Start a break"), options: [.foreground])
        let snooze = UNNotificationAction(identifier: snoozeActionID, title: String(localized: "In 15 minutes"), options: [])
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
    static func reschedule(preferences: Preferences, lastBreak: Date?, now: Date = Date()) async {
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)

        guard preferences.remindersEnabled else { return }
        let status = await status()
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        let dates = ReminderPlanner.upcoming(from: now, lastBreak: lastBreak, schedule: preferences.schedule)
        for (i, date) in dates.enumerated() {
            let content = makeContent(index: i, minutes: preferences.breakLength.minutes)
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: idPrefix + "\(Int(date.timeIntervalSince1970))", content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    static func scheduleOneOff(after seconds: TimeInterval, minutes: Int) async {
        let content = makeContent(index: Int.random(in: 0..<10), minutes: minutes)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let request = UNNotificationRequest(identifier: idPrefix + "oneoff.\(UUID().uuidString)", content: content, trigger: trigger)
        try? await center.add(request)
    }

    private static func makeContent(index: Int, minutes: Int) -> UNMutableNotificationContent {
        let name = Brand.mascotName
        let copies: [(String, String)] = [
            (String(localized: "\(name) looked up from the laptop"), String(localized: "A \(minutes)-minute break is ready when you are.")),
            (String(localized: "Time to unshrimp"), String(localized: "Uncurl for \(minutes) minutes, then back to it.")),
            (String(localized: "Stretch o'clock"), String(localized: "\(name)'s antennae are tingling. Quick break?")),
            (String(localized: "Shoulders, are you there?"), String(localized: "Roll them out with \(name). \(minutes) minutes.")),
            (String(localized: "Tiny break, big sigh"), String(localized: "Stand, reach, roll. \(name) will guide you."))
        ]
        let pick = copies[index % copies.count]
        let content = UNMutableNotificationContent()
        content.title = pick.0
        content.body = pick.1
        content.sound = .default
        content.categoryIdentifier = categoryID
        content.interruptionLevel = .active
        return content
    }
}
