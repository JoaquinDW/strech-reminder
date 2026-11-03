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

    var totalSeconds: Int { minutes > 0 ? minutes * 60 : moves.count * secondsPerMove }

    /// Distribute remainder seconds rather than silently shortening a five-minute break.
    func seconds(for index: Int) -> Int {
        guard !moves.isEmpty else { return 0 }
        return totalSeconds / moves.count + (index < totalSeconds % moves.count ? 1 : 0)
    }
}

enum DemoLibrary {
    static let disclaimer = String(localized: "Demo routine for this prototype. Placeholder moves, not professionally reviewed guidance. Move gently and skip anything that doesn't feel right.")

    static let moves: [Move] = [
        Move(id: "neck-tilt", name: String(localized: "Ear to shoulder"),
             cue: String(localized: "Sit tall. Let one ear drift toward its shoulder, breathe, then switch sides. Keep it easy."),
             focus: [.neck], pose: .neckTilt),
        Move(id: "head-turn", name: String(localized: "Look over your shoulder"),
             cue: String(localized: "Sit tall. Turn your head slowly to look over one shoulder, pause, come back, then the other side. Chin level."),
             focus: [.neck], pose: .headTurn),
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
             focus: [.shoulders], pose: .chestOpener),
        Move(id: "reach-up", name: String(localized: "Big reach"),
             cue: String(localized: "Reach both arms up and forward, grow tall, then breathe out and lower."),
             focus: [.lowerBack], pose: .reachUp),
        Move(id: "twist", name: String(localized: "Seated twist"),
             cue: String(localized: "Sit tall and turn gently to one side, then the other. Let your breath lead."),
             focus: [.lowerBack], pose: .twist),
        Move(id: "cat-cow", name: String(localized: "Seated curl and arch"),
             cue: String(localized: "Hands on knees. Round your back like a shrimp, then lift your chest. Repeat slowly."),
             focus: [.lowerBack], pose: .catCow),
        Move(id: "march", name: String(localized: "March in place"),
             cue: String(localized: "Stand up and march on the spot. Let your arms swing."),
             focus: [.lowerBack], pose: .march),
        Move(id: "side-reach", name: String(localized: "Side reach"),
             cue: String(localized: "Reach one arm overhead and lean gently to the other side. Switch."),
             focus: [.lowerBack], pose: .sideReach)
    ]

    static func move(_ id: String) -> Move { moves.first { $0.id == id } ?? moves[0] }

    /// The single move used in the onboarding demo.
    static var demoMove: Move { move("shrug") }

    static var availableMoves: [Move] { moves.filter { $0.media != nil } }

    /// How many past move ids are kept for rotation.
    static let historyLimit = 40

    /// Builds a routine from the chosen areas, taking turns between them and starting with the moves
    /// that came up least recently, so consecutive breaks don't feel the same.
    static func routine(length: BreakLength, focus: Set<FocusArea>, recent: [String] = []) -> Routine {
        let count: Int
        switch length {
        case .two: count = 4
        case .three: count = 6
        case .five: count = 8
        }
        let areas = focus.isEmpty ? Set(FocusArea.allCases) : focus
        // Never-seen moves first, then the ones seen longest ago; catalog order breaks ties.
        func lastSeen(_ move: Move) -> Int { recent.lastIndex(of: move.id) ?? -1 }
        var remaining = availableMoves.enumerated()
            .sorted { (lastSeen($0.element), $0.offset) < (lastSeen($1.element), $1.offset) }
            .map(\.element)

        var picked: [Move] = []
        let turns = FocusArea.allCases.filter(areas.contains)
        var turn = 0, misses = 0
        while picked.count < count, misses < turns.count {
            let area = turns[turn % turns.count]
            turn += 1
            if let i = remaining.firstIndex(where: { $0.focus.contains(area) }) {
                picked.append(remaining.remove(at: i))
                misses = 0
            } else {
                misses += 1
            }
        }
        // The chosen areas ran out: borrow from the others before repeating anything.
        picked += remaining.prefix(count - picked.count)
        // Still short only when the whole catalog is smaller than the break.
        let firstRound = picked
        while picked.count < count, !firstRound.isEmpty {
            picked.append(firstRound[picked.count % firstRound.count])
        }
        return Routine(moves: picked, secondsPerMove: length.minutes * 60 / count, minutes: length.minutes, focus: areas)
    }
}
