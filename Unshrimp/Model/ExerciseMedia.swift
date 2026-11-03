import Foundation

/// Only selected, usable demonstrations belong in the automatic routine pool.
/// The full placeholder catalog is retained in DemoLibrary for future content work.
struct ExerciseMedia: Hashable {
    let moveID: String
    let switchesSides: Bool

    var resourceName: String { "exercise-\(moveID)" }
    var url: URL? { Bundle.main.url(forResource: resourceName, withExtension: "mp4") }
    func poster(_ phase: String) -> String { "\(resourceName)-\(phase)" }

    static let selected: [String: ExerciseMedia] = Dictionary(uniqueKeysWithValues: [
        ExerciseMedia(moveID: "shoulder-roll", switchesSides: false),
        ExerciseMedia(moveID: "shrug", switchesSides: false),
        ExerciseMedia(moveID: "neck-tilt", switchesSides: true),
        // Turns to both sides within the clip, so it plays as one continuous move.
        ExerciseMedia(moveID: "head-turn", switchesSides: false),
        ExerciseMedia(moveID: "chest-opener", switchesSides: false),
        ExerciseMedia(moveID: "twist", switchesSides: true),
        ExerciseMedia(moveID: "side-reach", switchesSides: true)
    ].map { ($0.moveID, $0) })
}

extension Move {
    var media: ExerciseMedia? { ExerciseMedia.selected[id] }

    /// Stable per occurrence, so recomputing a view never changes the joke.
    func companionComment(occurrence: Int) -> String {
        if occurrence > 0 {
            switch id {
            case "neck-tilt": return String(localized: "My neck has requested an encore.")
            case "head-turn": return String(localized: "Still nobody behind me. Good.")
            case "shoulder-roll": return String(localized: "Still a shrimp. A little less folded.")
            case "shrug": return String(localized: "That backpack was heavier than I thought.")
            case "chest-opener": return String(localized: "Coffee can wait for round two.")
            case "twist": return String(localized: "Work is still there. I checked.")
            case "side-reach": return String(localized: "The weekend is getting closer.")
            default: return String(localized: "Another round? My desk can wait.")
            }
        }
        switch id {
        case "neck-tilt": return String(localized: "My neck asked for a break too.")
        case "head-turn": return String(localized: "Checking for sneaky seagulls.")
        case "shrug": return String(localized: "Putting down my imaginary backpack.")
        case "chest-opener": return String(localized: "Making room for one more coffee.")
        case "twist": return String(localized: "Checking if work is still behind me.")
        case "side-reach": return String(localized: "Reaching for the weekend.")
        default: return String(localized: "I could use that one…")
        }
    }
}
