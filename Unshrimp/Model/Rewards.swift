import Foundation

/// Cosmetic unlocks for Kip's desk. Costs are cumulative energy totals.
enum DeskItem: String, Codable, CaseIterable, Identifiable, Hashable {
    case plant, mug, lamp, poster, lights, snail, cat, rug
    var id: String { rawValue }

    var cost: Int {
        switch self {
        case .plant: 20
        case .mug: 60
        case .lamp: 110
        case .poster: 170
        case .lights: 240
        case .snail: 320
        case .cat: 410
        case .rug: 520
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
        case .cat: String(localized: "Napping cat")
        case .rug: String(localized: "Stripy rug")
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
        case .cat: String(localized: "Naps on the rug. Stretches more than anyone here.")
        case .rug: String(localized: "Somewhere soft to land after a big reach.")
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
    /// Set when this break moved Kip to a new growth stage.
    var newStage: Int? = nil
    var newWearable: Wearable? = nil
    /// How the person said the break felt, so Kip can answer on the reward screen.
    var feel: BreakFeel? = nil
    /// What the streak did, when there's a streak to talk about.
    var streak: StreakUpdate? = nil

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

/// Things Kip can wear. Most arrive with a growth stage; the rest come from streak milestones.
/// Either way they come from showing up over time rather than from energy.
enum Wearable: String, Codable, CaseIterable, Identifiable, Hashable {
    case sweatband, specs, beanie, flower, crown
    case cap, starfish, headphones, captain
    var id: String { rawValue }

    /// The streak length that brings this one, or nil for growth-stage wearables.
    var streakMilestone: Int? {
        switch self {
        case .cap: 7
        case .starfish: 14
        case .headphones: 30
        case .captain: 100
        default: nil
        }
    }

    var title: String {
        switch self {
        case .sweatband: String(localized: "Sweatband")
        case .specs: String(localized: "Little specs")
        case .beanie: String(localized: "Bobble beanie")
        case .flower: String(localized: "Antenna flower")
        case .crown: String(localized: "Tiny crown")
        case .cap: String(localized: "Sporty cap")
        case .starfish: String(localized: "Starfish clip")
        case .headphones: String(localized: "Focus headphones")
        case .captain: String(localized: "Captain's hat")
        }
    }

    var blurb: String {
        switch self {
        case .sweatband: String(localized: "\(Brand.mascotName) insists it's for style, not sweat.")
        case .specs: String(localized: "For reading the screen without leaning in.")
        case .beanie: String(localized: "Cozy, slightly too big, very bouncy.")
        case .flower: String(localized: "Grows a little every time \(Brand.mascotName) reaches up.")
        case .crown: String(localized: "Royalty of the uncurled. Earned, not given.")
        case .cap: String(localized: "A week in a row. Worn slightly sideways, on purpose.")
        case .starfish: String(localized: "Two weeks of showing up. The starfish says hi.")
        case .headphones: String(localized: "A whole month. Plays nothing but ocean sounds.")
        case .captain: String(localized: "A hundred days. \(Brand.mascotName) now runs this ship.")
        }
    }
}

/// Kip's long-term growth: every completed break loosens the curl a little,
/// and each stage brings something new to wear.
struct KipGrowth: Equatable {
    struct Stage: Equatable {
        let breaks: Int
        let wearable: Wearable?
    }

    static let stages: [Stage] = [
        Stage(breaks: 0, wearable: nil),
        Stage(breaks: 3, wearable: .sweatband),
        Stage(breaks: 8, wearable: .specs),
        Stage(breaks: 15, wearable: .beanie),
        Stage(breaks: 25, wearable: .flower),
        Stage(breaks: 40, wearable: .crown)
    ]

    static func title(_ index: Int) -> String {
        switch index {
        case 0: String(localized: "Tightly curled")
        case 1: String(localized: "Loosening up")
        case 2: String(localized: "Unfurling")
        case 3: String(localized: "Stretchy")
        case 4: String(localized: "Limber")
        default: String(localized: "Fully unshrimped")
        }
    }

    let breaks: Int

    var stageIndex: Int { Self.stages.lastIndex { breaks >= $0.breaks } ?? 0 }
    var title: String { Self.title(stageIndex) }
    var nextStage: Stage? { Self.stages.indices.contains(stageIndex + 1) ? Self.stages[stageIndex + 1] : nil }

    /// 0 = a tight desk shrimp, 1 = as upright as Kip gets. Moves a little with every break.
    var uncurl: Double {
        let full = Double(Self.stages.last?.breaks ?? 1)
        return pow(min(1, Double(breaks) / full), 0.8)
    }

    var wearables: [Wearable] { Self.stages.prefix(stageIndex + 1).compactMap(\.wearable) }

    /// Breaks into the current stage and breaks the stage takes, for a progress bar.
    var progress: (current: Int, needed: Int)? {
        guard let next = nextStage else { return nil }
        let start = Self.stages[stageIndex].breaks
        return (breaks - start, next.breaks - start)
    }

    static func stageWearable(_ wearable: Wearable) -> Int {
        stages.firstIndex { $0.wearable == wearable } ?? 0
    }

    /// "2 more breaks until Unfurling" style hint, or nil once Kip is fully grown.
    var nextHint: String? {
        guard let p = progress else { return nil }
        let left = p.needed - p.current
        let next = Self.title(stageIndex + 1)
        return left == 1
            ? String(localized: "One more break until \(next)")
            : String(localized: "\(left) more breaks until \(next)")
    }
}
