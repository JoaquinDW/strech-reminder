import Foundation

/// Cosmetic unlocks for Kip's desk. Costs are cumulative energy totals.
enum DeskItem: String, Codable, CaseIterable, Identifiable, Hashable {
    case plant, mug, lamp, poster, lights, snail
    var id: String { rawValue }

    var cost: Int {
        switch self {
        case .plant: 20
        case .mug: 60
        case .lamp: 110
        case .poster: 170
        case .lights: 240
        case .snail: 320
        }
    }

    var title: String {
        switch self {
        case .plant: String(localized: "Desk sprout")
        case .mug: String(localized: "Cozy mug")
        case .lamp: String(localized: "Little lamp")
        case .poster: String(localized: "Wave poster")
        case .lights: String(localized: "Fairy lights")
        case .snail: String(localized: "Desk snail")
        }
    }

    var blurb: String {
        switch self {
        case .plant: String(localized: "A small green friend. Kip waters it between stretches.")
        case .mug: String(localized: "Steamy, warm, and very good at being held.")
        case .lamp: String(localized: "A soft glow for late afternoons.")
        case .poster: String(localized: "A reminder that the ocean is still out there.")
        case .lights: String(localized: "Twinkly. Obviously.")
        case .snail: String(localized: "A very slow coworker. Extremely supportive.")
        }
    }
}

/// One line on the reward screen.
struct EnergyLine: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let amount: Int
}

/// What a completed break produced.
struct BreakResult: Equatable {
    var lines: [EnergyLine]
    var energyBefore: Int
    var energyAfter: Int
    var newlyUnlocked: [DeskItem]
    var breaksToday: Int
    var goal: Int
    var reachedGoalNow: Bool
    var adventureStop: Int

    var earned: Int { energyAfter - energyBefore }
}

enum EnergyRules {
    static let base = 10
    static let firstEver = 10
    static let welcomeBack = 10
    static let spacedOut = 5
    static let goalBonus = 15
    /// Minutes since the previous break for the "spread out" bonus.
    static let spacingMinutes: Double = 60
    /// Days away before the welcome-back bonus.
    static let absenceDays = 2

    static func award(at date: Date, history: [BreakRecord], breaksTodayBefore: Int, goal: Int, calendar: Calendar = .current) -> [EnergyLine] {
        var lines = [EnergyLine(label: String(localized: "Break complete"), amount: base)]
        if let last = history.max(by: { $0.date < $1.date }) {
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: last.date), to: calendar.startOfDay(for: date)).day ?? 0
            if days >= absenceDays {
                lines.append(EnergyLine(label: String(localized: "Welcome back"), amount: welcomeBack))
            } else if calendar.isDate(last.date, inSameDayAs: date), date.timeIntervalSince(last.date) >= spacingMinutes * 60 {
                lines.append(EnergyLine(label: String(localized: "Nicely spread out"), amount: spacedOut))
            }
        } else {
            lines.append(EnergyLine(label: String(localized: "Very first break"), amount: firstEver))
        }
        if breaksTodayBefore + 1 == goal {
            lines.append(EnergyLine(label: String(localized: "Daily goal reached"), amount: goalBonus))
        }
        return lines
    }
}

/// The weekly adventure: each day the goal is met moves Kip one stop along the trail.
enum Adventure {
    static let stops: [String] = [
        String(localized: "Kelp Corner"),
        String(localized: "Sandbar Café"),
        String(localized: "Lighthouse Steps"),
        String(localized: "Coral Arch"),
        String(localized: "The Big Shell")
    ]
}
