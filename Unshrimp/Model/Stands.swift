import Foundation

/// A quick stand: one standing move of 20 to 60 seconds between breaks, to cut long
/// stretches of sitting. Done from the reminder itself or from a one-move screen.
struct StandMove: Identifiable, Hashable {
    let id: String
    let name: String
    /// One line telling what to do, used on the screen and in the reminder.
    let cue: String
    let seconds: Int
    let pose: MovePose

    /// GENERAL WELLNESS CONTENT. Simple standing moves; have them reviewed by a physiotherapist
    /// alongside the break routines before making any claims about pain.
    static let all: [StandMove] = [
        StandMove(id: "stand-march", name: String(localized: "March in place"),
                  cue: String(localized: "Stand up and march on the spot, arms swinging. Easy pace."),
                  seconds: 45, pose: .march),
        StandMove(id: "stand-water", name: String(localized: "Water run"),
                  cue: String(localized: "Get up and refill your water. Take the long way back."),
                  seconds: 60, pose: .march),
        StandMove(id: "stand-reach", name: String(localized: "Standing reach"),
                  cue: String(localized: "Stand tall, reach both arms up, then lean gently to each side."),
                  seconds: 30, pose: .sideReach),
        StandMove(id: "stand-backbend", name: String(localized: "Standing back bend"),
                  cue: String(localized: "Hands on your lower back, lift your chest and lean back a little. Breathe, come back. Repeat 5 times."),
                  seconds: 30, pose: .chestOpener),
        StandMove(id: "stand-sit-to-stand", name: String(localized: "Sit to stand"),
                  cue: String(localized: "Stand up from your chair and sit back down slowly, 5 times. Use your hands if you need to."),
                  seconds: 30, pose: .march),
        StandMove(id: "stand-wall-pushup", name: String(localized: "Wall push-ups"),
                  cue: String(localized: "Hands on a wall at shoulder height. Bend your elbows to bring your chest in, push back. 8 times."),
                  seconds: 45, pose: .shoulderRoll),
        StandMove(id: "stand-blade-squeeze", name: String(localized: "Shoulder blade squeeze"),
                  cue: String(localized: "Standing, squeeze your shoulder blades together and down, hold 2 seconds, let go. 10 times."),
                  seconds: 30, pose: .chestOpener),
        StandMove(id: "stand-look-far", name: String(localized: "Look far away"),
                  cue: String(localized: "Stand by a window and look at something far away for 20 seconds. Let your eyes soften."),
                  seconds: 20, pose: .headTurn)
    ]

    static func move(_ id: String?) -> StandMove? { all.first { $0.id == id } }

    /// The move for a reminder slot. Deterministic, so rescheduling keeps the same move per slot.
    static func pick(seed: Int) -> StandMove {
        all[((seed % all.count) + all.count) % all.count]
    }
}

struct StandRecord: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var moveID: String
    var energy: Int
}

enum StandSource: String {
    case reminderAction = "reminder_action"
    case reminderScreen = "reminder_screen"
    case app
}

/// How a break felt right after. Asked on the break's last screen, in place of a plain "yes".
enum BreakFeel: String, Codable, CaseIterable {
    case looser, same, bothered
}

/// One stiffness score (0 none … 10 a lot) for one area, from onboarding or the weekly check-in.
struct StiffnessRecord: Codable, Equatable {
    var date: Date
    var area: FocusArea
    var score: Int

    static let range = 0...10
}

/// First and latest stiffness for one area, once there are at least two check-ins a week apart.
struct StiffnessTrend: Equatable, Identifiable {
    let area: FocusArea
    let first: Int
    let latest: Int
    var id: FocusArea { area }
    var change: Int { latest - first }

    static func trends(_ records: [StiffnessRecord], upTo end: Date = .distantFuture, minimumSpan: TimeInterval = 6 * 86_400) -> [StiffnessTrend] {
        FocusArea.allCases.compactMap { area in
            let mine = records.filter { $0.area == area && $0.date <= end }.sorted { $0.date < $1.date }
            guard let first = mine.first, let latest = mine.last,
                  latest.date.timeIntervalSince(first.date) >= minimumSpan else { return nil }
            return StiffnessTrend(area: area, first: first.score, latest: latest.score)
        }
    }
}

enum StandRules {
    static let energy = 3
    /// Daily cap on stand energy, so stands support the desk instead of racing through it.
    static let dailyEnergyCap = 30
    /// Skipped or ignored stand reminders in a row before the next one comes later.
    static let backoffAfter = 3
    static let backoffMinutes = 30
    /// A stand reminder never lands this close (or closer) to a break reminder.
    static let gapAroundBreakMinutes = 15
    /// Moves that bothered someone stay out of routines this long.
    static let avoidDays = 14
    /// Days between weekly stiffness check-ins.
    static let checkinDays = 7

    static func energy(standsTodayEnergy: Int) -> Int {
        max(0, min(energy, dailyEnergyCap - standsTodayEnergy))
    }
}
