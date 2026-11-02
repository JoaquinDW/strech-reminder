import XCTest
import UIKit
@testable import Unshrimp

final class ExerciseSessionTests: XCTestCase {
    private let origin = Date(timeIntervalSince1970: 1_000)
    private func at(_ seconds: Double) -> Date { origin.addingTimeInterval(seconds) }

    private func session(_ id: String = "shrug", duration: Int = 20) -> ExerciseSession {
        let move = DemoLibrary.move(id)
        return ExerciseSession(routine: Routine(moves: [move], secondsPerMove: duration, minutes: 0, focus: move.focus))
    }

    func testPreparationDoesNotConsumeMovementTime() {
        let s = session()
        s.start(at: at(0))
        s.tick(at: at(2))
        XCTAssertEqual(s.phase, .preparing)
        XCTAssertEqual(s.work.elapsed, 0)
        s.tick(at: at(3))
        XCTAssertEqual(s.phase, .moving)
        XCTAssertEqual(s.secondsLeft, 20)
        s.tick(at: at(8))
        XCTAssertEqual(s.secondsLeft, 15)
    }

    func testPauseAndResumePreservesMovementAcrossLongInterruption() {
        let s = session()
        s.start(at: at(0)); s.tick(at: at(3)); s.tick(at: at(8))
        s.pause(at: at(8))
        s.tick(at: at(100))
        XCTAssertEqual(s.work.elapsed, 5)
        XCTAssertFalse(s.isRunning)
        s.resume(at: at(100)); s.tick(at: at(104))
        XCTAssertEqual(s.work.elapsed, 9)
        XCTAssertEqual(s.secondsLeft, 11)
    }

    func testPreparationCanBePausedToo() {
        let s = session()
        s.start(at: at(0)); s.pause(at: at(1))
        s.tick(at: at(100))
        XCTAssertEqual(s.secondsLeft, 2)
        s.resume(at: at(100)); s.tick(at: at(102))
        XCTAssertEqual(s.phase, .moving)
        XCTAssertEqual(s.work.elapsed, 0)
    }

    func testBilateralMoveSwitchesOnceWithoutConsumingActiveSeconds() {
        let s = session("neck-tilt")
        s.start(at: at(0)); s.tick(at: at(3)); s.tick(at: at(13))
        XCTAssertEqual(s.phase, .switchingSides)
        XCTAssertTrue(s.isMirrored)
        XCTAssertEqual(s.work.elapsed, 10)
        s.tick(at: at(16))
        XCTAssertEqual(s.phase, .moving)
        XCTAssertEqual(s.work.elapsed, 10)
        s.tick(at: at(25))
        XCTAssertEqual(s.phase, .moving)
        s.tick(at: at(26))
        XCTAssertTrue(s.isComplete)
        XCTAssertFalse(s.isRunning)
    }

    func testSkippingStartsFreshPreparationAndClearsMirroring() {
        let s = ExerciseSession(routine: Routine(moves: [DemoLibrary.move("neck-tilt"), DemoLibrary.move("shrug")], secondsPerMove: 20, minutes: 0, focus: [.neck]))
        s.start(at: at(0)); s.tick(at: at(3)); s.tick(at: at(13))
        s.advance(at: at(14))
        XCTAssertEqual(s.index, 1)
        XCTAssertEqual(s.phase, .preparing)
        XCTAssertFalse(s.isMirrored)
        XCTAssertEqual(s.work.elapsed, 0)
        XCTAssertEqual(s.secondsLeft, 3)
    }

    func testStartingRunningTimerAgainDoesNotLoseElapsedTime() {
        var timer = MoveTimer(duration: 20)
        timer.start(at: at(0)); timer.tick(at: at(5)); timer.start(at: at(5)); timer.tick(at: at(8))
        XCTAssertEqual(timer.elapsed, 8)
    }

    func testRoutineUsesSelectedMediaAndPreservesExactMovementDuration() {
        for length in BreakLength.allCases {
            let routine = DemoLibrary.routine(length: length, focus: [.wholeBody], seed: 3)
            XCTAssertTrue(routine.moves.allSatisfy { $0.media != nil })
            XCTAssertFalse(routine.moves.contains { ["nod", "reach-up", "cat-cow", "march"].contains($0.id) })
            XCTAssertEqual(routine.moves.indices.reduce(0) { $0 + routine.seconds(for: $1) }, length.minutes * 60)
            XCTAssertEqual(routine.moves.count, length == .two ? 4 : length == .three ? 6 : 8)
        }
    }

    func testBundledMediaAndReducedMotionPosesExist() {
        for move in DemoLibrary.availableMoves {
            XCTAssertNotNil(move.media?.url, "Missing bundled video: \(move.id)")
            for pose in ["start", "mid", "end"] {
                XCTAssertNotNil(UIImage(named: move.media!.poster(pose)), "Missing pose: \(move.id) \(pose)")
            }
        }
    }

    func testCompanionDoesNotRepeatCommentsWithinLongRoutine() {
        let routine = DemoLibrary.routine(length: .five, focus: [.neck], seed: 4)
        let comments = routine.moves.enumerated().map { index, move in
            move.companionComment(occurrence: routine.moves.prefix(index).filter { $0.id == move.id }.count)
        }
        XCTAssertEqual(Set(comments).count, comments.count)
    }
}
