import SwiftUI
import UserNotifications

@main
struct taskappwatchiosApp: App {
    init() {
        NotificationManager.shared.setup()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

// MARK: - Navigation State
// Plain singleton with a callback — no Combine/ObservableObject needed.
// HomeView registers the callback on appear; NotificationManager calls it on tap.
final class NavigationState {
    static let shared = NavigationState()

    // HomeView sets this when it mounts
    var openRecord: ((_ startISO: String, _ intervalMinutes: Int) -> Void)?

    func triggerRecord(startISO: String, intervalMinutes: Int) {
        DispatchQueue.main.async {
            self.openRecord?(startISO, intervalMinutes)
        }
    }
}

// MARK: - Notification Manager
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    static let kPendingStartTime       = "pending_record_startTime"
    static let kPendingIntervalMinutes = "pending_record_interval"

    func setup() {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // Show banner even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // User tapped notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info      = response.notification.request.content.userInfo
        let startTime = info[NotificationManager.kPendingStartTime] as? String ?? ""
        let interval  = info[NotificationManager.kPendingIntervalMinutes] as? Int
                        ?? UserDefaults.standard.integer(forKey: "watch_interval").nonZeroOr(60)

        // Write to UserDefaults for cold-start case (app was fully dead)
        UserDefaults.standard.set(startTime, forKey: NotificationManager.kPendingStartTime)
        UserDefaults.standard.set(interval,  forKey: NotificationManager.kPendingIntervalMinutes)

        // If app is live, navigate immediately via callback
        NavigationState.shared.triggerRecord(startISO: startTime, intervalMinutes: interval)

        completionHandler()
    }

    // Call from SplashView after login — handles cold-start case
    static func flushPendingNavIfNeeded() {
        let d = UserDefaults.standard
        guard let startTime = d.string(forKey: kPendingStartTime), !startTime.isEmpty else { return }
        let interval = d.integer(forKey: kPendingIntervalMinutes).nonZeroOr(60)
        d.removeObject(forKey: kPendingStartTime)
        d.removeObject(forKey: kPendingIntervalMinutes)
        NavigationState.shared.triggerRecord(startISO: startTime, intervalMinutes: interval)
    }
}

private extension Int {
    func nonZeroOr(_ fallback: Int) -> Int { self == 0 ? fallback : self }
}
