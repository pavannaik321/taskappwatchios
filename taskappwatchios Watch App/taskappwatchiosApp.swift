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

// MARK: - Notification Manager
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    // UserDefaults keys for pending deep-link (mirrors Wear OS kPendingNav pattern)
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

    // User tapped notification → store payload so HomeView can deep-link to Record screen
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        let startTime = info[NotificationManager.kPendingStartTime] as? String ?? ""
        let interval  = info[NotificationManager.kPendingIntervalMinutes] as? Int
                        ?? UserDefaults.standard.integer(forKey: "watch_interval").nonZeroOr(60)

        UserDefaults.standard.set(startTime, forKey: NotificationManager.kPendingStartTime)
        UserDefaults.standard.set(interval,  forKey: NotificationManager.kPendingIntervalMinutes)

        completionHandler()
    }

    /// Reads and clears the pending deep-link. Returns nil if none.
    static func consumePendingNav() -> (startISO: String, intervalMinutes: Int)? {
        let d = UserDefaults.standard
        guard let startTime = d.string(forKey: kPendingStartTime), !startTime.isEmpty else { return nil }
        let interval = d.integer(forKey: kPendingIntervalMinutes).nonZeroOr(60)
        d.removeObject(forKey: kPendingStartTime)
        d.removeObject(forKey: kPendingIntervalMinutes)
        return (startTime, interval)
    }
}

private extension Int {
    func nonZeroOr(_ fallback: Int) -> Int { self == 0 ? fallback : self }
}
