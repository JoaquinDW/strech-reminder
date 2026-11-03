import XCTest
@testable import Unshrimp

final class AnalyticsTests: XCTestCase {
    func testSyntheticRunsNeverSendEvenWithDebugOptIn() {
        let environment = ["POSTHOG_ENABLE_DEBUG": "1"]
        for argument in ["-resetData", "-seedWeek", "-seedGrowth", "-testReward", "-testStartFromNotification"] {
            XCTAssertFalse(Analytics.isEnabled(environment: environment, arguments: ["Unshrimp", argument]))
        }
        for marker in ["XCTestConfigurationFilePath", "XCTestBundlePath", "XCODE_RUNNING_FOR_PREVIEWS"] {
            var testEnvironment = environment
            testEnvironment[marker] = "1"
            XCTAssertFalse(Analytics.isEnabled(environment: testEnvironment, arguments: []))
        }
    }

    func testDebugRequiresExplicitOptIn() {
        #if DEBUG
        XCTAssertFalse(Analytics.isEnabled(environment: [:], arguments: []))
        #else
        XCTAssertTrue(Analytics.isEnabled(environment: [:], arguments: []))
        #endif
        XCTAssertTrue(Analytics.isEnabled(environment: ["POSTHOG_ENABLE_DEBUG": "1"], arguments: []))
    }

    func testClosingOverviewDoesNotCountAsStartedOrAbandoned() {
        var events = [String]()
        var breakAnalytics = BreakAnalytics(minutes: 3, source: .app) { name, _ in events.append(name) }
        breakAnalytics.abandon(reason: "dismissed")
        XCTAssertTrue(events.isEmpty)
    }

    func testCompletedBreakCannotAlsoBeAbandonedOrDoubleCounted() {
        var events = [(String, [String: Any])]()
        var breakAnalytics = BreakAnalytics(minutes: 2, source: .reminder) { events.append(($0, $1)) }
        breakAnalytics.start()
        breakAnalytics.start()
        breakAnalytics.complete(routineReachedEnd: false, isFirstBreak: true, breaksToday: 1)
        breakAnalytics.complete(routineReachedEnd: false, isFirstBreak: true, breaksToday: 1)
        breakAnalytics.abandon(reason: "dismissed")

        XCTAssertEqual(events.map(\.0), ["break_started", "break_completed"])
        XCTAssertEqual(events[0].1["break_id"] as? String, events[1].1["break_id"] as? String)
        XCTAssertEqual(events[1].1["source"] as? String, "reminder")
        XCTAssertEqual(events[1].1["duration_minutes"] as? Int, 2)
        XCTAssertEqual(events[1].1["routine_reached_end"] as? Bool, false)
        XCTAssertEqual(events[1].1["is_first_break"] as? Bool, true)
    }

    func testDeclinedBreakHasOneOutcomeAndCannotBecomeCompleted() {
        var events = [String]()
        var breakAnalytics = BreakAnalytics(minutes: 3, source: .app) { name, _ in events.append(name) }
        breakAnalytics.start()
        breakAnalytics.abandon(reason: "not_confirmed")
        breakAnalytics.abandon(reason: "dismissed")
        breakAnalytics.complete(routineReachedEnd: true, isFirstBreak: true, breaksToday: 1)
        XCTAssertEqual(events, ["break_started", "break_abandoned"])
    }
}
