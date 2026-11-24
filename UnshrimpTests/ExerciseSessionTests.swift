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
            let routine = DemoLibrary.routine(length: length, focus: Set(FocusArea.allCases))
            XCTAssertTrue(routine.moves.allSatisfy { $0.media != nil })
            XCTAssertFalse(routine.moves.contains { ["nod", "reach-up", "cat-cow"].contains($0.id) })
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
        let routine = DemoLibrary.routine(length: .five, focus: [.neck])
        let comments = routine.moves.enumerated().map { index, move in
            move.companionComment(occurrence: routine.moves.prefix(index).filter { $0.id == move.id }.count)
        }
        XCTAssertEqual(Set(comments).count, comments.count)
    }

    func testRoutineDoesNotRepeatWhileCatalogHasEnoughMoves() {
        let routine = DemoLibrary.routine(length: .three, focus: [.lowerBack])
        XCTAssertEqual(Set(routine.moves.map(\.id)).count, routine.moves.count)
        // Chosen area first, then borrowed moves.
        XCTAssertTrue(routine.moves.prefix(2).allSatisfy { $0.focus.contains(.lowerBack) })
    }

    func testRoutineTakesTurnsBetweenChosenAreas() {
        let routine = DemoLibrary.routine(length: .two, focus: [.neck, .lowerBack])
        XCTAssertTrue(routine.moves[0].focus.contains(.neck))
        XCTAssertTrue(routine.moves[1].focus.contains(.lowerBack))
    }

    func testNextBreakStartsWithMovesNotSeenLately() {
        let shoulders = DemoLibrary.availableMoves.filter { $0.focus.contains(.shoulders) }.map(\.id)
        // Everything seen once, oldest first: the next break starts from the oldest.
        let routine = DemoLibrary.routine(length: .two, focus: [.shoulders], recent: shoulders)
        XCTAssertEqual(routine.moves.first?.id, shoulders.first)
        // A move that never came up beats all of them.
        let fresh = DemoLibrary.routine(length: .two, focus: [.shoulders], recent: Array(shoulders.dropFirst()))
        XCTAssertEqual(fresh.moves.first?.id, shoulders.first)
        XCTAssertEqual(fresh.moves.dropFirst().first?.id, shoulders.dropFirst().first)
    }

    func testOldWholeBodyChoiceBecomesEveryArea() throws {
        let json = #"{"focusAreas":["wholeBody"],"dailyGoal":5}"#.data(using: .utf8)!
        let prefs = try JSONDecoder().decode(Preferences.self, from: json)
        XCTAssertEqual(prefs.focusAreas, Set(FocusArea.allCases))
        XCTAssertEqual(prefs.dailyGoal, 5)
        let record = try JSONDecoder().decode([FocusArea].self, from: #"["back","wholeBody"]"#.data(using: .utf8)!)
        XCTAssertEqual(record, [.lowerBack, .lowerBack])
    }
}

final class KipGrowthTests: XCTestCase {
    func testStagesUnlockWearablesInOrder() {
        XCTAssertEqual(KipGrowth(breaks: 0).stageIndex, 0)
        XCTAssertEqual(KipGrowth(breaks: 0).wearables, [])
        XCTAssertEqual(KipGrowth(breaks: 3).wearables, [.sweatband])
        XCTAssertEqual(KipGrowth(breaks: 14).wearables, [.sweatband, .specs])
        XCTAssertEqual(KipGrowth(breaks: 99).wearables, Wearable.allCases.filter { $0.streakMilestone == nil })
        XCTAssertNil(KipGrowth(breaks: 40).progress)
    }

    func testUncurlGrowsWithEveryBreakAndCaps() {
        var last = -1.0
        for n in 0...40 {
            let u = KipGrowth(breaks: n).uncurl
            XCTAssertGreaterThan(u, last)
            last = u
        }
        XCTAssertEqual(KipGrowth(breaks: 80).uncurl, 1)
    }

    func testProgressCountsFromCurrentStage() {
        let p = KipGrowth(breaks: 10).progress
        XCTAssertEqual(p?.current, 2)
        XCTAssertEqual(p?.needed, 7)
    }

    func testOldSavedDataStillLoads() throws {
        let json = #"{"hasOnboarded":true,"energy":42,"unlocked":["plant"],"breaks":[]}"#
        let data = try JSONDecoder().decode(AppData.self, from: Data(json.utf8))
        XCTAssertTrue(data.hasOnboarded)
        XCTAssertEqual(data.energy, 42)
        XCTAssertEqual(data.unlocked, [.plant])
        XCTAssertNil(data.outfit)
    }
}

final class KipVoiceTests: XCTestCase {
    private let context = KipVoice.Context(minutes: 3, focus: [.neck], look: KipLook(uncurl: 0.2, wearable: .sweatband),
                                           stage: 1, breaksToday: 0, goal: 3)
    private func slot(_ hour: Int, index: Int, count: Int = 5) -> KipVoice.Slot {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date(timeIntervalSince1970: 1_800_000_000))!
        return KipVoice.Slot(date: date, index: index, count: count, isToday: false)
    }

    func testSameSlotAlwaysGetsTheSameWords() {
        XCTAssertEqual(KipVoice.reminder(slot: slot(11, index: 2), context: context),
                       KipVoice.reminder(slot: slot(11, index: 2), context: context))
    }

    func testFirstAndLastNudgesHaveTheirOwnLines() {
        let firsts = (0..<10).map { i -> KipVoice.Line in
            var s = slot(9, index: 0)
            s.date = s.date.addingTimeInterval(Double(i) * 86_400)
            return KipVoice.reminder(slot: s, context: context)
        }
        XCTAssertTrue(firsts.allSatisfy { !$0.title.isEmpty && !$0.body.isEmpty })
        XCTAssertEqual(KipVoice.reminder(slot: slot(17, index: 4), context: context).title, String(localized: "Last stretch of the day"))
    }

    func testOneShortOfTheGoalSaysSoForToday() {
        var c = context
        c.breaksToday = 2
        var s = slot(13, index: 2)
        s.isToday = true
        XCTAssertEqual(KipVoice.reminder(slot: s, context: c).title, String(localized: "One more and we hit our goal"))
    }
}
