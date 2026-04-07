import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Request notification permissions
        UNUserNotificationCenter.current().delegate = self
        NotificationManager.shared.requestPermission()
        
        // Schedule midnight reset check (DispatchQueue-based)
        MidnightResetScheduler.shared.scheduleCheck()

        // Also arm HabitTracker's own RunLoop timer for in-process midnight reset
        HabitTracker.shared.scheduleMidnightReset()

        return true
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}

// MARK: - Midnight Reset Scheduler

class MidnightResetScheduler {
    static let shared = MidnightResetScheduler()
    private init() {}
    
    func scheduleCheck() {
        // Calculate time until next midnight
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()),
              let midnight = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: tomorrow) else {
            return
        }
        
        let timeUntilMidnight = midnight.timeIntervalSinceNow
        
        DispatchQueue.main.asyncAfter(deadline: .now() + timeUntilMidnight) { [weak self] in
            self?.executeMidnightReset()
            self?.scheduleCheck() // Reschedule for the next midnight
        }
    }
    
    private func executeMidnightReset() {
        let tracker = HabitTracker.shared
        
        if tracker.isOverDailyGoal {
            // Post notification for GameScene to handle the reset cutscene
            NotificationCenter.default.post(
                name: .midnightProgressResetTriggered,
                object: nil
            )
        }
        
        // Start a new day in the tracker
        tracker.rollOverToNewDay()
    }
}

// MARK: - Custom Notification Names

extension Notification.Name {
    static let midnightProgressResetTriggered = Notification.Name("midnightProgressResetTriggered")
    static let cigaretteLogged = Notification.Name("cigaretteLogged")
    static let dailyGoalExceeded = Notification.Name("dailyGoalExceeded")
    static let dailyReset        = Notification.Name("dailyReset")
}
