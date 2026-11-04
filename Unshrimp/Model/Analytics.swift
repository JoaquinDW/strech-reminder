import Foundation
import PostHog

/// One anonymous installation identity; no account, work schedule, focus areas or per-area
/// stiffness is sent. How a break felt and a check-in's average score are, as the privacy page says.
enum Analytics {
    private static var configured = false

    static func setup() {
        guard !configured, isEnabled(environment: ProcessInfo.processInfo.environment,
                                     arguments: ProcessInfo.processInfo.arguments) else { return }
        let environment = ProcessInfo.processInfo.environment
        let token = environment["POSTHOG_PROJECT_TOKEN"]
            ?? Bundle.main.object(forInfoDictionaryKey: "PostHogProjectToken") as? String ?? ""
        let host = environment["POSTHOG_HOST"]
            ?? Bundle.main.object(forInfoDictionaryKey: "PostHogHost") as? String ?? ""
        guard token.hasPrefix("phc_"), let url = URL(string: host),
              url.scheme == "https", url.host != nil else {
            NSLog("Unshrimp: analytics disabled — missing PostHog token or host.")
            return
        }

        let config = PostHogConfig(projectToken: token, host: host)
        config.captureApplicationLifecycleEvents = true
        config.captureScreenViews = false
        config.captureElementInteractions = false
        config.rageClickConfig.enabled = false
        config.sessionReplay = false
        config.surveys = false
        config.preloadFeatureFlags = false
        config.personProfiles = .identifiedOnly
        #if DEBUG
        let buildEnvironment = "debug"
        #else
        let isTestFlight = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        let buildEnvironment = isTestFlight ? "testflight" : "production"
        #endif
        config.setBeforeSend { event in
            event.properties["environment"] = buildEnvironment
            return event
        }
        PostHogSDK.shared.setup(config)
        configured = true
    }

    static func isEnabled(environment: [String: String], arguments: [String]) -> Bool {
        guard environment["XCTestConfigurationFilePath"] == nil,
              environment["XCTestBundlePath"] == nil,
              environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1",
              !arguments.contains(where: { $0.hasPrefix("-test") || $0.hasPrefix("-seed") || $0 == "-resetData" })
        else { return false }
        #if DEBUG
        return environment["POSTHOG_ENABLE_DEBUG"] == "1"
        #else
        return true
        #endif
    }

    static func capture(_ event: String, properties: [String: Any] = [:]) {
        guard configured else { return }
        PostHogSDK.shared.capture(event, properties: properties)
    }

    static func flush() {
        guard configured else { return }
        PostHogSDK.shared.flush()
    }
}

enum BreakSource: String {
    case app, reminder
}

/// A displayed routine is not a started break. Emit at most one start and one outcome.
struct BreakAnalytics {
    private let capture: (String, [String: Any]) -> Void
    private let properties: [String: Any]
    private(set) var hasStarted = false
    private(set) var hasEnded = false

    init(minutes: Int, source: BreakSource,
         capture: @escaping (String, [String: Any]) -> Void = Analytics.capture) {
        self.capture = capture
        properties = ["break_id": UUID().uuidString, "duration_minutes": minutes, "source": source.rawValue]
    }

    mutating func start() {
        guard !hasStarted, !hasEnded else { return }
        hasStarted = true
        capture("break_started", properties)
    }

    mutating func complete(routineReachedEnd: Bool, isFirstBreak: Bool, breaksToday: Int) {
        guard hasStarted, !hasEnded else { return }
        hasEnded = true
        var result = properties
        result["routine_reached_end"] = routineReachedEnd
        result["is_first_break"] = isFirstBreak
        result["breaks_today"] = breaksToday
        capture("break_completed", result)
    }

    mutating func abandon(reason: String) {
        guard hasStarted, !hasEnded else { return }
        hasEnded = true
        var result = properties
        result["reason"] = reason
        capture("break_abandoned", result)
    }
}
