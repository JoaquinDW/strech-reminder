import SwiftUI
import UserNotifications

@main
struct UnshrimpApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.light)
                .tint(Palette.coral)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await model.refreshNotificationStatus()
                await model.rescheduleReminders()
            }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            if model.data.hasOnboarded {
                HomeView().transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                OnboardingFlow().transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: model.data.hasOnboarded)
        .fontDesign(.rounded)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        NotificationManager.registerCategories()
        return true
    }

    // Show reminders as banners even while the app is open.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let action = response.actionIdentifier
        await MainActor.run {
            let model = AppModel.shared
            switch action {
            case NotificationManager.snoozeActionID:
                Task { await model.snooze() }
            case NotificationManager.startActionID, UNNotificationDefaultActionIdentifier:
                if model.data.hasOnboarded { model.breakRequestedFromNotification = true }
            default:
                break
            }
        }
    }
}
