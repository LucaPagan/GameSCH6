import UserNotifications

// MARK: - Notification Manager

/// Schedules and manages local notifications for the habit tracker.
class NotificationManager {
    
    static let shared = NotificationManager()
    private init() {}
    
    // MARK: - Permissions
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if granted {
                self.scheduleAllNotifications()
            }
        }
    }
    
    // MARK: - Schedule All
    
    func scheduleAllNotifications() {
        scheduleMorningCheckin()
        scheduleEveningMotivation()
    }
    
    // MARK: - Morning Check-in (9:00 AM)
    
    private func scheduleMorningCheckin() {
        let content = UNMutableNotificationContent()
        content.title = "AD ASTRA ☀️"
        content.body = "Set your goal for today. Your character is waiting."
        content.sound = .default
        content.categoryIdentifier = "MORNING_CHECKIN"
        
        var dateComponents = DateComponents()
        dateComponents.hour = 9
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "morning_checkin",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Evening Motivation (8:00 PM)
    
    private func scheduleEveningMotivation() {
        let content = UNMutableNotificationContent()
        content.title = "AD ASTRA 🌙"
        
        let tracker = HabitTracker.shared
        let count = tracker.cigarettesLoggedToday
        let goal = tracker.dailyCigaretteGoal
        
        if count <= goal {
            content.body = "You've smoked \(count) today. Goal: \(goal). Great discipline! 💪"
        } else {
            content.body = "You've smoked \(count) today (goal: \(goal)). Tomorrow is a new chance. 🌅"
        }
        
        content.sound = .default
        content.categoryIdentifier = "EVENING_MOTIVATION"
        
        var dateComponents = DateComponents()
        dateComponents.hour = 20
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "evening_motivation",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Midnight Warning (11:30 PM, only if over goal)
    
    func scheduleMidnightWarning() {
        let tracker = HabitTracker.shared
        guard tracker.isOverDailyGoal else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "⚠️ AD ASTRA"
        content.body = "You're over your goal. The midnight reset is coming in 30 minutes."
        content.sound = .default
        content.categoryIdentifier = "MIDNIGHT_WARNING"
        
        var dateComponents = DateComponents()
        dateComponents.hour = 23
        dateComponents.minute = 30
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: "midnight_warning",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Streak Celebration
    
    func scheduleStreakCelebration(days: Int, rewardName: String) {
        let content = UNMutableNotificationContent()
        content.title = "🔥 \(days) Days!"
        content.body = "You've unlocked the \(rewardName)! Keep climbing!"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "streak_\(days)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Clear All
    
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
