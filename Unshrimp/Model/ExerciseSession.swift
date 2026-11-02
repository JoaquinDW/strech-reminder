import Foundation
import Observation

/// Preparation, active movement and side changes share one pause/resume boundary.
@Observable
final class ExerciseSession {
    enum Phase: Equatable { case preparing, moving, switchingSides, complete }

    let routine: Routine
    let preparationDuration: Double
    private(set) var index = 0
    private(set) var phase: Phase = .preparing
    private(set) var work: MoveTimer
    private(set) var preparation: MoveTimer
    private(set) var hasBegun = false
    private(set) var isMirrored = false
    private(set) var playbackRevision = 0

    init(routine: Routine, preparationDuration: Double = 3) {
        precondition(!routine.moves.isEmpty, "A session needs at least one move")
        self.routine = routine
        self.preparationDuration = preparationDuration
        work = MoveTimer(duration: Double(routine.seconds(for: 0)))
        preparation = MoveTimer(duration: preparationDuration)
    }

    var move: Move { routine.moves[index] }
    var isPreparing: Bool { phase == .preparing || phase == .switchingSides }
    var isRunning: Bool { isPreparing ? preparation.isRunning : work.isRunning }
    var isComplete: Bool { phase == .complete }
    var secondsLeft: Int { isPreparing ? preparation.secondsLeft : work.secondsLeft }
    var progress: Double { work.progress }
    var occurrence: Int { routine.moves.prefix(index).filter { $0.id == move.id }.count }
    var showsComment: Bool { phase == .moving && isRunning && work.elapsed >= 4 && work.elapsed < 9 }

    var phaseTitle: String {
        if !isRunning && hasBegun && !isComplete { return String(localized: "Paused. Take your time.") }
        switch phase {
        case .preparing: return String(localized: "Get ready")
        case .switchingSides: return String(localized: "Switch sides")
        case .moving:
            if move.media?.switchesSides == true {
                return isMirrored ? String(localized: "Other side") : String(localized: "First side")
            }
            return String(localized: "Move at your own pace")
        case .complete: return String(localized: "All done")
        }
    }

    func start(at date: Date = Date()) {
        guard !hasBegun else { return }
        hasBegun = true
        preparation.start(at: date)
    }

    func pause(at date: Date = Date()) {
        work.pause(at: date)
        preparation.pause(at: date)
    }

    func resume(at date: Date = Date()) {
        guard hasBegun, !isComplete else { return }
        if isPreparing { preparation.start(at: date) } else { work.start(at: date) }
    }

    func toggle(at date: Date = Date()) {
        if !hasBegun { start(at: date) }
        else if isRunning { pause(at: date) }
        else { resume(at: date) }
    }

    func tick(at date: Date = Date()) {
        guard isRunning, !isComplete else { return }
        if isPreparing {
            preparation.tick(at: date)
            if preparation.isComplete {
                phase = .moving
                work.start(at: date)
            }
            return
        }
        work.tick(at: date)
        if work.isComplete {
            advance(at: date)
        } else if move.media?.switchesSides == true, !isMirrored, work.elapsed >= work.duration / 2 {
            work.pause(at: date)
            isMirrored = true
            phase = .switchingSides
            playbackRevision += 1
            preparation.restart(duration: preparationDuration, at: date)
        }
    }

    func advance(at date: Date = Date()) {
        pause(at: date)
        if index == routine.moves.count - 1 {
            phase = .complete
        } else {
            index += 1
            phase = .preparing
            isMirrored = false
            playbackRevision += 1
            work = MoveTimer(duration: Double(routine.seconds(for: index)))
            preparation.restart(duration: preparationDuration, at: date)
        }
    }
}
