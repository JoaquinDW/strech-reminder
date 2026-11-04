import XCTest

final class TrainingMediaUITests: XCTestCase {
    private var app: XCUIApplication!

    private func tap(_ label: String) {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 8), "Missing \(label)")
        button.tap()
    }

    private func startTraining(reducedMotion: Bool = false, largeType: Bool = false) {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-testTraining", "-skipPaywall", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if reducedMotion { app.launchArguments.append("-testReduceMotion") }
        if largeType { app.launchArguments.append("-testLargeType") }
        app.launch()
        tap("Let's move")
    }

    private func screenshot(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            let url = URL(fileURLWithPath: dir)
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            try? shot.pngRepresentation.write(to: url.appendingPathComponent(name + ".png"))
        }
    }

    private var demonstration: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "exercise-demonstration").firstMatch
    }

    func testVideoPauseReplayDialogBackgroundAndEveryMove() {
        startTraining()
        XCTAssertTrue(demonstration.waitForExistence(timeout: 8))
        let playing = NSPredicate(format: "value CONTAINS %@", "Playing")
        expectation(for: playing, evaluatedWith: demonstration)
        waitForExpectations(timeout: 12)
        sleep(5)
        screenshot("training-video-with-kip")

        tap("Pause")
        let countdown = app.descendants(matching: .any).matching(identifier: "exercise-countdown").firstMatch
        let frozen = countdown.label
        sleep(2)
        XCTAssertEqual(countdown.label, frozen)
        screenshot("training-paused-frame")

        tap("Replay demo")
        expectation(for: playing, evaluatedWith: demonstration)
        waitForExpectations(timeout: 4)
        XCTAssertEqual(countdown.label, frozen, "Preview must not consume exercise time")
        tap("End break")
        screenshot("training-end-dialog")
        tap("Keep going")
        XCTAssertTrue(app.buttons["Resume"].exists, "Canceling from a paused session should remain paused")

        tap("Resume")
        tap("End break")
        tap("Keep going")
        XCTAssertTrue(app.buttons["Pause"].exists, "Keep going restores a running session")
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["Resume"].waitForExistence(timeout: 5))
        screenshot("training-background-resumed-paused")
        tap("Resume")

        // The long routine exercises six assets plus two repeated moves with distinct view identities.
        for index in 0..<8 {
            XCTAssertTrue(demonstration.exists)
            expectation(for: playing, evaluatedWith: demonstration)
            waitForExpectations(timeout: 10)
            screenshot("training-step-\(index + 1)")
            tap(index == 7 ? "Finish" : "Next move")
        }
        XCTAssertTrue(app.buttons["Looser"].waitForExistence(timeout: 5))
    }

    func testReducedMotionKeepsAReadableMovementGuide() {
        startTraining(reducedMotion: true)
        XCTAssertTrue(demonstration.waitForExistence(timeout: 8))
        sleep(4)
        XCTAssertTrue(String(describing: demonstration.value).contains("Still movement guide"))
        tap("Movement")
        screenshot("training-reduced-motion-guide")
        tap("Return")
        tap("Start pose")
        XCTAssertTrue(app.buttons["Pause"].exists)
    }

    func testBilateralMovePreparesThenDemonstratesTheOtherSide() {
        startTraining()
        let phase = app.staticTexts["exercise-phase"]
        expectation(for: NSPredicate(format: "label == %@", "First side"), evaluatedWith: phase)
        waitForExpectations(timeout: 8)
        sleep(3)
        screenshot("training-first-side")
        expectation(for: NSPredicate(format: "label == %@", "Switch sides"), evaluatedWith: phase)
        waitForExpectations(timeout: 23)
        screenshot("training-switch-sides")
        expectation(for: NSPredicate(format: "label == %@", "Other side"), evaluatedWith: phase)
        waitForExpectations(timeout: 6)
        sleep(3)
        screenshot("training-other-side")
        XCTAssertTrue(String(describing: demonstration.value).contains("Playing"))
    }

    func testCompactTrainingAtLargeTextSize() {
        startTraining(reducedMotion: true, largeType: true)
        XCTAssertTrue(demonstration.waitForExistence(timeout: 8))
        sleep(5)
        screenshot("training-large-type")
        tap("Pause")
        XCTAssertTrue(app.buttons["Resume"].exists)
        app.swipeUp()
        screenshot("training-large-type-scrolled")
    }
}
