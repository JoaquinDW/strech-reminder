import SwiftUI
import UserNotifications

@main
struct UnshrimpApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel.shared
    @State private var subscription = Subscription.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(\.kipLook, model.look)
                .environment(\.exerciseMotionOverride, testReducedMotion)
                .transformEnvironment(\.dynamicTypeSize) { value in
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("-testLargeType") { value = .accessibility3 }
                    #endif
                }
                .preferredColorScheme(.light)
                .tint(Palette.coral)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { Analytics.flush() }
            guard phase == .active else { return }
            Task {
                await model.refreshNotificationStatus()
                await model.rescheduleReminders()
            }
        }
    }

    private var testReducedMotion: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-testReduceMotion")
        #else
        false
        #endif
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var subscription = Subscription.shared
    @State private var rewardPreview = RootView.rewardPreviewOnce

    var body: some View {
        ZStack {
            if let result = rewardPreview {
                RewardView(result: result) { rewardPreview = nil }
                    .background(Palette.ivory.ignoresSafeArea())
            } else if trainingPreview {
                BreakFlowView(routine: DemoLibrary.routine(length: .five, focus: Set(FocusArea.allCases)))
            } else if model.data.hasOnboarded && !subscription.isActive {
                // Hard paywall: right after onboarding, and again whenever the subscription lapses.
                PaywallView().transition(.opacity)
            } else if model.data.hasOnboarded {
                HomeView().transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                OnboardingFlow().transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: model.data.hasOnboarded)
        .animation(.easeInOut(duration: 0.4), value: subscription.isActive)
        .fontDesign(.rounded)
    }

    /// Debug: -testReward records one break and opens its reward screen, to check unlock moments.
    // Static so it runs once, not on every RootView init.
    private static let rewardPreviewOnce = makeRewardPreview()

    private static func makeRewardPreview() -> BreakResult? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-testReward") {
            return AppModel.shared.recordBreak(minutes: 3, focus: [.neck, .shoulders])
        }
        #endif
        return nil
    }

    private var trainingPreview: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-testTraining")
        #else
        false
        #endif
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Analytics.setup()
        UNUserNotificationCenter.current().delegate = self
        NotificationManager.registerCategories()
        return true
    }

    // Show reminders as banners even while the app is open.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let category = response.notification.request.content.categoryIdentifier
        if category == NotificationManager.standCategoryID {
            await handleStand(response)
            return
        }
        if category == NotificationManager.recapCategoryID {
            await MainActor.run {
                Analytics.capture("weekly_recap_reminder_opened")
                let model = AppModel.shared
                if model.data.hasOnboarded { model.recapRequested = true }
            }
            return
        }
        guard category == NotificationManager.categoryID else { return }
        let action = response.actionIdentifier
        await MainActor.run {
            let model = AppModel.shared
            switch action {
            case NotificationManager.snoozeActionID:
                Analytics.capture("reminder_snoozed", properties: ["snooze_minutes": Int(NotificationManager.snoozeMinutes)])
                Analytics.flush()
                Task { await model.snooze() }
            case NotificationManager.startActionID:
                Analytics.capture("reminder_opened", properties: ["action": "start_break"])
                // "Stretch with Kip now" goes straight into the first move.
                guard model.data.hasOnboarded else { break }
                model.skipBreakIntro = true
                model.breakRequestedFromNotification = true
            case UNNotificationDefaultActionIdentifier:
                Analytics.capture("reminder_opened", properties: ["action": "open"])
                if model.data.hasOnboarded { model.breakRequestedFromNotification = true }
            default:
                break
            }
        }
    }

    /// "Done, I stood up" and "Not now" run in the background and finish before returning, so the
    /// stand is saved and reminders are replanned even though the app never comes forward.
    private func handleStand(_ response: UNNotificationResponse) async {
        let moveID = response.notification.request.content.userInfo[NotificationManager.standMoveKey] as? String
        switch response.actionIdentifier {
        case NotificationManager.standDoneActionID:
            await Task { @MainActor in
                await AppModel.shared.recordStand(moveID: moveID ?? "", source: .reminderAction)
                Analytics.flush()
            }.value
        case NotificationManager.standSkipActionID:
            await Task { @MainActor in
                await AppModel.shared.skipStand(moveID: moveID)
                Analytics.flush()
            }.value
        case NotificationManager.standShowActionID, UNNotificationDefaultActionIdentifier:
            await MainActor.run {
                let model = AppModel.shared
                Analytics.capture("stand_reminder_opened")
                if model.data.hasOnboarded { model.standRequested = moveID ?? StandMove.all[0].id }
            }
        default:
            break
        }
    }
}
