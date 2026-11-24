import Foundation

enum FocusArea: String, Codable, CaseIterable, Identifiable, Hashable {
    // Raw value "back" is kept so data saved before the rename still loads.
    case neck, shoulders, lowerBack = "back"
    var id: String { rawValue }

    /// Builds before 1.1 also offered "wholeBody"; its moves now live under the lower back.
    static let legacyWholeBody = "wholeBody"

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = FocusArea(rawValue: raw) ?? .lowerBack
    }

    var title: String {
        switch self {
        case .neck: String(localized: "Neck")
        case .shoulders: String(localized: "Shoulders")
        case .lowerBack: String(localized: "Lower back")
        }
    }

    var symbol: String {
        switch self {
        case .neck: "person.bust"
        case .shoulders: "figure.arms.open"
        case .lowerBack: "figure.flexibility"
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
    /// Short standing moves between breaks, to cut long stretches of sitting.
    var standsEnabled = true
    var standIntervalMinutes = 45

    static let goalRange = 1...8
    static let standIntervalOptions = [30, 45, 60]

    /// Stand rhythm suggested by what usually gets in the way: people who mostly forget get
    /// the regular rhythm; people unsure what to do get fewer, so breaks keep center stage.
    static func suggestedStandInterval(for friction: Friction) -> Int {
        friction == .unsure ? 60 : 45
    }

    init() {}

    // Decoded field by field; someone who picked "Whole body" before it was removed gets every area.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Preferences()
        friction = try c.decodeIfPresent(Friction.self, forKey: .friction) ?? d.friction
        let areas = try c.decodeIfPresent([String].self, forKey: .focusAreas)
        if let areas {
            focusAreas = areas.contains(FocusArea.legacyWholeBody)
                ? Set(FocusArea.allCases)
                : Set(areas.compactMap(FocusArea.init(rawValue:)))
            if focusAreas.isEmpty { focusAreas = d.focusAreas }
        }
        breakLength = try c.decodeIfPresent(BreakLength.self, forKey: .breakLength) ?? d.breakLength
        dailyGoal = try c.decodeIfPresent(Int.self, forKey: .dailyGoal) ?? d.dailyGoal
        schedule = try c.decodeIfPresent(WorkSchedule.self, forKey: .schedule) ?? d.schedule
        remindersEnabled = try c.decodeIfPresent(Bool.self, forKey: .remindersEnabled) ?? d.remindersEnabled
        standsEnabled = try c.decodeIfPresent(Bool.self, forKey: .standsEnabled) ?? d.standsEnabled
        standIntervalMinutes = try c.decodeIfPresent(Int.self, forKey: .standIntervalMinutes) ?? d.standIntervalMinutes
    }
}

struct BreakRecord: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var minutes: Int
    var focus: [FocusArea]
    var energy: Int
    /// How the body felt right after, when the user said. Older records have none.
    var feel: BreakFeel? = nil
}

/// Everything persisted to disk.
struct AppData: Codable {
    var hasOnboarded = false
    var preferences = Preferences()
    var breaks: [BreakRecord] = []
    var energy = 0
    var unlocked: [DeskItem] = []
    /// What Kip is wearing. New wearables are put on when they unlock.
    var outfit: Wearable?
    /// Move ids from past breaks, oldest first, so new routines can favor what hasn't come up lately.
    var recentMoves: [String] = []
    /// Short standing moves done between breaks.
    var stands: [StandRecord] = []
    /// Stiffness scores from onboarding and the weekly check-in.
    var stiffness: [StiffnessRecord] = []
    /// Moves the user said bothered them, with when, so routines leave them out for a while.
    var avoidedMoves: [String: Date] = [:]
    /// Stand reminders answered "Not now" in a row; resets when a stand is done.
    var standSkipStreak = 0
    /// Last time the weekly stiffness check-in was answered or skipped.
    var lastStiffnessPrompt: Date?
    /// Shell guards, misses and milestones. The streak itself is worked out from `breaks`.
    var streak = StreakState()

    init() {}

    // Decoded field by field so data saved by older builds keeps loading as fields are added.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hasOnboarded = try c.decodeIfPresent(Bool.self, forKey: .hasOnboarded) ?? false
        preferences = try c.decodeIfPresent(Preferences.self, forKey: .preferences) ?? Preferences()
        breaks = try c.decodeIfPresent([BreakRecord].self, forKey: .breaks) ?? []
        energy = try c.decodeIfPresent(Int.self, forKey: .energy) ?? 0
        unlocked = try c.decodeIfPresent([DeskItem].self, forKey: .unlocked) ?? []
        outfit = try c.decodeIfPresent(Wearable.self, forKey: .outfit)
        recentMoves = try c.decodeIfPresent([String].self, forKey: .recentMoves) ?? []
        stands = try c.decodeIfPresent([StandRecord].self, forKey: .stands) ?? []
        stiffness = try c.decodeIfPresent([StiffnessRecord].self, forKey: .stiffness) ?? []
        avoidedMoves = try c.decodeIfPresent([String: Date].self, forKey: .avoidedMoves) ?? [:]
        standSkipStreak = try c.decodeIfPresent(Int.self, forKey: .standSkipStreak) ?? 0
        lastStiffnessPrompt = try c.decodeIfPresent(Date.self, forKey: .lastStiffnessPrompt)
        streak = (try? c.decodeIfPresent(StreakState.self, forKey: .streak)) ?? StreakState()
    }
}
