import Foundation

enum FocusArea: String, Codable, CaseIterable, Identifiable, Hashable {
    case neck, shoulders, back, wholeBody
    var id: String { rawValue }

    var title: String {
        switch self {
        case .neck: String(localized: "Neck")
        case .shoulders: String(localized: "Shoulders")
        case .back: String(localized: "Back")
        case .wholeBody: String(localized: "Whole body")
        }
    }

    var symbol: String {
        switch self {
        case .neck: "person.bust"
        case .shoulders: "figure.arms.open"
        case .back: "figure.flexibility"
        case .wholeBody: "figure.walk"
        }
    }

    static func summary(_ areas: Set<FocusArea>) -> String {
        let ordered = allCases.filter { areas.contains($0) }
        if ordered.isEmpty || ordered.count == allCases.count { return String(localized: "Everything") }
        return ordered.map(\.title).formatted(.list(type: .and))
    }
}

enum Friction: String, Codable, CaseIterable, Identifiable {
    case forget, unsure, both
    var id: String { rawValue }
}

enum BreakLength: Int, Codable, CaseIterable, Identifiable {
    case two = 2, three = 3, five = 5
    var id: Int { rawValue }
    var minutes: Int { rawValue }
    var label: String { String(localized: "\(rawValue) min") }
}

struct WorkSchedule: Codable, Equatable {
    /// Calendar weekday numbers (1 = Sunday … 7 = Saturday).
    var workdays: Set<Int> = [2, 3, 4, 5, 6]
    var startMinute: Int = 9 * 60
    var endMinute: Int = 18 * 60
    var intervalMinutes: Int = 90

    static let intervalOptions = [45, 60, 90, 120]

    var workdaysSummary: String {
        let cal = Calendar.current
        let symbols = cal.shortWeekdaySymbols
        let order = (0..<7).map { (cal.firstWeekday - 1 + $0) % 7 + 1 }
        let days = order.filter { workdays.contains($0) }
        if days == [2, 3, 4, 5, 6] { return String(localized: "Mon–Fri") }
        if days.count == 7 { return String(localized: "Every day") }
        if days.isEmpty { return String(localized: "No workdays") }
        return days.map { symbols[$0 - 1] }.formatted(.list(type: .and))
    }

    var hoursSummary: String {
        "\(Self.timeString(startMinute))–\(Self.timeString(endMinute))"
    }

    static func timeString(_ minute: Int) -> String {
        var c = DateComponents()
        c.hour = minute / 60
        c.minute = minute % 60
        let d = Calendar.current.date(from: c) ?? Date()
        return d.formatted(date: .omitted, time: .shortened)
    }
}

struct Preferences: Codable, Equatable {
    var friction: Friction = .both
    var focusAreas: Set<FocusArea> = [.neck, .shoulders]
    var breakLength: BreakLength = .three
    var dailyGoal: Int = 3
    var schedule = WorkSchedule()
    var remindersEnabled = true

    static let goalRange = 1...8
}

struct BreakRecord: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var minutes: Int
    var focus: [FocusArea]
    var energy: Int
}

/// Everything persisted to disk.
struct AppData: Codable {
    var hasOnboarded = false
    var preferences = Preferences()
    var breaks: [BreakRecord] = []
    var energy = 0
    var unlocked: [DeskItem] = []
}
