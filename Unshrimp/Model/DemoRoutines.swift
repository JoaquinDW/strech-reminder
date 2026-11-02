import Foundation

/// PROTOTYPE CONTENT. These moves are generic placeholders written for the prototype.
/// They have not been reviewed by a physiotherapist or other professional and should be
/// replaced with professionally reviewed guidance before release.
struct Move: Identifiable, Hashable {
    let id: String
    let name: String
    let cue: String
    let focus: Set<FocusArea>
    let pose: MovePose
}

struct Routine: Hashable {
    var moves: [Move]
    var secondsPerMove: Int
    var minutes: Int
    var focus: Set<FocusArea>

    var totalSeconds: Int { moves.count * secondsPerMove }
}

enum DemoLibrary {
    static let disclaimer = String(localized: "Demo routine for this prototype. Placeholder moves, not professionally reviewed guidance. Move gently and skip anything that doesn't feel right.")

    static let moves: [Move] = [
        Move(id: "neck-tilt", name: String(localized: "Ear to shoulder"),
             cue: String(localized: "Sit tall. Let one ear drift toward its shoulder, breathe, then switch sides. Keep it easy."),
             focus: [.neck], pose: .neckTilt),
        Move(id: "nod", name: String(localized: "Slow yes, slow no"),
             cue: String(localized: "Nod gently a few times, then look slowly left and right. Small, comfortable range."),
             focus: [.neck], pose: .nod),
        Move(id: "shoulder-roll", name: String(localized: "Shoulder rolls"),
             cue: String(localized: "Roll both shoulders up, back and down in slow circles."),
             focus: [.shoulders], pose: .shoulderRoll),
        Move(id: "shrug", name: String(localized: "Shrug and drop"),
             cue: String(localized: "Lift your shoulders toward your ears, hold a moment, then let them drop."),
             focus: [.shoulders, .neck], pose: .shrug),
        Move(id: "chest-opener", name: String(localized: "Chest opener"),
             cue: String(localized: "Hold the sides of your chair, lift your chest and draw your shoulders gently back."),
             focus: [.shoulders, .back], pose: .chestOpener),
        Move(id: "reach-up", name: String(localized: "Big reach"),
             cue: String(localized: "Reach both arms up and forward, grow tall, then breathe out and lower."),
             focus: [.back, .wholeBody], pose: .reachUp),
        Move(id: "twist", name: String(localized: "Seated twist"),
             cue: String(localized: "Sit tall and turn gently to one side, then the other. Let your breath lead."),
             focus: [.back], pose: .twist),
        Move(id: "cat-cow", name: String(localized: "Seated curl and arch"),
             cue: String(localized: "Hands on knees. Round your back like a shrimp, then lift your chest. Repeat slowly."),
             focus: [.back], pose: .catCow),
        Move(id: "march", name: String(localized: "March in place"),
             cue: String(localized: "Stand up and march on the spot. Let your arms swing."),
             focus: [.wholeBody], pose: .march),
        Move(id: "side-reach", name: String(localized: "Side reach"),
             cue: String(localized: "Reach one arm overhead and lean gently to the other side. Switch."),
             focus: [.wholeBody, .back], pose: .sideReach)
    ]

    static func move(_ id: String) -> Move { moves.first { $0.id == id } ?? moves[0] }

    /// The single move used in the onboarding demo.
    static var demoMove: Move { move("shoulder-roll") }

    /// Builds a routine that favors the chosen areas and varies by day.
    static func routine(length: BreakLength, focus: Set<FocusArea>, seed: Int = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0) -> Routine {
        let count: Int
        switch length {
        case .two: count = 4
        case .three: count = 6
        case .five: count = 8
        }
        let areas = focus.isEmpty ? Set(FocusArea.allCases) : focus
        let preferred = moves.filter { !$0.focus.isDisjoint(with: areas) }
        let others = moves.filter { $0.focus.isDisjoint(with: areas) }
        let rotation = preferred.isEmpty ? 0 : seed % preferred.count
        var ordered = Array(preferred[rotation...] + preferred[..<rotation]) + others
        // Finish on something that gets you out of the chair when time allows.
        if count >= 6, let march = ordered.firstIndex(where: { $0.pose == .march }) {
            let m = ordered.remove(at: march)
            ordered.insert(m, at: min(count - 1, ordered.count))
        }
        let picked = Array(ordered.prefix(count))
        return Routine(moves: picked, secondsPerMove: length.minutes * 60 / count, minutes: length.minutes, focus: areas)
    }
}
