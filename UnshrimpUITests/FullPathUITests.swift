import XCTest

/// Walks the core path (onboarding → home → guided break → reward → updated home → relaunch)
/// and saves a screenshot at each step. Set SCREENSHOT_DIR (TEST_RUNNER_SCREENSHOT_DIR when
/// using xcodebuild) to also write PNGs to disk.
final class FullPathUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }

    func tapButton(_ label: String, timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) {
        var b = app.buttons[label].firstMatch
        if !b.waitForExistence(timeout: 1) {
            b = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
        }
        XCTAssertTrue(b.waitForExistence(timeout: timeout), "Missing button \(label)", file: file, line: line)
        b.tap()
    }

    func allowNotificationsIfAsked() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 4) { allow.tap() }
    }

    func testFullPath() {
        app.launchArguments = ["-resetData", "-skipPaywall"]
        app.launch()

        sleep(2)
        snap("01-welcome")
        tapButton("Let's get moving")

        sleep(1)
        tapButton("I'm not sure what to do")
        snap("02-friction")
        tapButton("Continue")

        sleep(1)
        tapButton("Lower back")
        snap("03-focus")
        tapButton("Continue")

        sleep(1)
        snap("04-demo")
        tapButton("Start the demo")
        sleep(3)
        snap("04b-demo-running")
        tapButton("Skip the demo")

        sleep(1)
        tapButton("2 minutes")
        snap("05-rhythm")
        tapButton("Continue")

        sleep(1)
        snap("06-schedule")
        tapButton("Continue")

        sleep(1)
        snap("07-reminders")
        // Permission may already be decided if the app was installed before.
        let turnOn = app.buttons["Turn on reminders"]
        if turnOn.waitForExistence(timeout: 2) {
            turnOn.tap()
            allowNotificationsIfAsked()
        }
        sleep(1)
        snap("07b-reminders-on")
        tapButton("Continue")

        sleep(2)
        snap("08-plan")
        tapButton("Go to my desk")

        sleep(2)
        snap("09-home-first-day")
        app.swipeUp()
        sleep(1)
        snap("09b-home-first-day-scrolled")
        app.swipeDown()

        tapButton("Start a break")
        sleep(1)
        snap("10-break-intro")
        tapButton("Let's move")
        sleep(2)
        snap("11-move")
        tapButton("Pause")
        sleep(1)
        snap("11b-move-paused")
        tapButton("Resume")
        tapButton("Next move")
        sleep(1)
        snap("11c-move-2")
        tapButton("Next move")
        tapButton("Next move")
        sleep(1)
        tapButton("Finish")
        sleep(1)
        snap("12-confirm")
        tapButton("Looser")
        sleep(3)
        snap("13-reward")
        tapButton("Back to work")
        sleep(1)
        snap("14-home-after-break")
        sleep(2)
        snap("14b-home-after-break-settled")
        app.swipeUp()
        sleep(1)
        snap("14c-home-after-scrolled")

        tapButton("Reminder settings")
        sleep(1)
        snap("15-settings")
        tapButton("Done")

        // Persistence: relaunch without reset
        app.terminate()
        app.launchArguments = ["-skipPaywall"]
        app.launch()
        sleep(2)
        snap("16-relaunch")
        XCTAssertTrue(app.staticTexts["1"].exists || app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'of 3 breaks'")).count > 0)
    }

    func testSeededWeek() {
        app.launchArguments = ["-resetData", "-seedWeek", "-skipPaywall"]
        app.launch()
        sleep(2)
        snap("20-home-seeded")
        app.swipeUp()
        sleep(1)
        snap("20b-home-seeded-scrolled")
    }
}
