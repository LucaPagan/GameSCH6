import Foundation
import Combine

// MARK: - Habit Tracker

/// Tracks daily smoking behavior and streak data.
/// Persists to UserDefaults for lightweight, reliable storage.
/// This is the "Reality Mirror" — bridging real-world behavior to game state.
final class HabitTracker: ObservableObject {
    
    static let shared = HabitTracker()
    
    // MARK: Published State
    
    /// Today's cigarette goal (set by user each morning)
    @Published var dailyCigaretteGoal: Int {
        didSet { save() }
    }
    
    /// Cigarettes logged today
    @Published private(set) var cigarettesLoggedToday: Int
    
    /// Timestamps of each cigarette logged today
    @Published private(set) var todayCigaretteTimestamps: [Date]
    
    /// Current smoke-free streak (consecutive days with 0 cigarettes)
    @Published private(set) var currentStreak: Int
    
    /// Longest ever streak
    @Published private(set) var longestStreak: Int
    
    /// Whether the daily setup has been completed today
    @Published private(set) var hasCompletedDailySetup: Bool
    
    // MARK: Computed
    
    /// Whether the user needs to set up their daily goal (first launch of the day)
    var needsDailySetup: Bool {
        !hasCompletedDailySetup || !Calendar.current.isDateInToday(lastSetupDate ?? .distantPast)
    }
    
    /// Whether the user has exceeded their daily goal
    var isOverDailyGoal: Bool {
        cigarettesLoggedToday > dailyCigaretteGoal
    }
    
    /// How many cigarettes remain before reaching the daily goal
    var cigarettesRemaining: Int {
        max(0, dailyCigaretteGoal - cigarettesLoggedToday)
    }
    
    /// Whether the progress reset is pending (user exceeded goal, midnight hasn't hit yet)
    var progressResetPending: Bool {
        isOverDailyGoal
    }
    
    /// Yesterday's cigarette count (for the morning setup screen)
    var yesterdayCigaretteCount: Int {
        UserDefaults.standard.integer(forKey: Keys.yesterdayCigarettes)
    }
    
    // MARK: Private
    
    private var lastSetupDate: Date? {
        UserDefaults.standard.object(forKey: Keys.lastSetupDate) as? Date
    }
    
    // MARK: Initialization
    
    private init() {
        let defaults = UserDefaults.standard
        
        // Check if we need to roll over to a new day
        let lastDate = defaults.object(forKey: Keys.lastSetupDate) as? Date
        let isNewDay = lastDate == nil || !Calendar.current.isDateInToday(lastDate!)
        
        if isNewDay {
            self.cigarettesLoggedToday = 0
            self.todayCigaretteTimestamps = []
            self.hasCompletedDailySetup = false
        } else {
            self.cigarettesLoggedToday = defaults.integer(forKey: Keys.cigarettesToday)
            self.todayCigaretteTimestamps = (defaults.array(forKey: Keys.timestamps) as? [Date]) ?? []
            self.hasCompletedDailySetup = defaults.bool(forKey: Keys.hasCompletedSetup)
        }
        
        self.dailyCigaretteGoal = defaults.integer(forKey: Keys.dailyGoal) == 0
            ? 5 // Default goal
            : defaults.integer(forKey: Keys.dailyGoal)
        self.currentStreak = defaults.integer(forKey: Keys.currentStreak)
        self.longestStreak = defaults.integer(forKey: Keys.longestStreak)
    }
    
    // MARK: Actions
    
    /// Complete the daily setup with a goal
    func completeDailySetup(goal: Int) {
        dailyCigaretteGoal = max(0, goal)
        hasCompletedDailySetup = true
        UserDefaults.standard.set(Date(), forKey: Keys.lastSetupDate)
        UserDefaults.standard.set(true, forKey: Keys.hasCompletedSetup)
        save()
    }
    
    /// Log a cigarette. Returns the new count.
    @discardableResult
    func logCigarette() -> Int {
        cigarettesLoggedToday += 1
        todayCigaretteTimestamps.append(Date())
        save()
        
        // Post in-game notification
        NotificationCenter.default.post(name: .cigaretteLogged, object: nil, userInfo: [
            "count": cigarettesLoggedToday,
            "goal": dailyCigaretteGoal
        ])
        
        // Check if we just exceeded the goal
        if cigarettesLoggedToday == dailyCigaretteGoal + 1 {
            NotificationCenter.default.post(name: .dailyGoalExceeded, object: nil)
        }
        
        return cigarettesLoggedToday
    }
    
    /// Roll over to a new day. Called at midnight.
    func rollOverToNewDay() {
        // Archive yesterday's data
        UserDefaults.standard.set(cigarettesLoggedToday, forKey: Keys.yesterdayCigarettes)
        
        // Update streak
        if cigarettesLoggedToday == 0 {
            currentStreak += 1
            longestStreak = max(longestStreak, currentStreak)
        } else {
            currentStreak = 0
        }
        
        // Append to history
        appendToHistory(date: Date(), count: cigarettesLoggedToday, goal: dailyCigaretteGoal)
        
        // Reset for new day
        cigarettesLoggedToday = 0
        todayCigaretteTimestamps = []
        hasCompletedDailySetup = false
        
        save()
    }
    
    /// SOLO PER DEBUG: Imposta il conteggio sigarette
    func debugSetCigarettes(count: Int) {
        cigarettesLoggedToday = max(0, count)
        save()
    }
    
    /// Contextual message based on current smoking state
    func contextualMessage() -> String {
        if cigarettesLoggedToday == 0 {
            return "Clean lungs, full power. Keep climbing! 💪"
        } else if cigarettesLoggedToday == 1 {
            return "First one today. You're still strong."
        } else if cigarettesLoggedToday <= dailyCigaretteGoal / 2 {
            return "Still under your goal. Stay aware."
        } else if cigarettesLoggedToday == dailyCigaretteGoal {
            return "You've hit your limit. The pigeons are circling. 🐦"
        } else if isOverDailyGoal {
            return "Over your goal. Midnight will not be kind. ⚠️"
        } else {
            return "Halfway to your limit. The pigeons are circling."
        }
    }
    
    // MARK: Streak Rewards
    
    /// Milestone days that unlock cosmetic rewards
    static let streakMilestones = [3, 7, 14, 30, 60, 90, 180, 365]
    
    /// Returns the list of milestones the player has achieved
    var achievedMilestones: [Int] {
        Self.streakMilestones.filter { longestStreak >= $0 }
    }
    
    // MARK: Persistence
    
    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(dailyCigaretteGoal, forKey: Keys.dailyGoal)
        defaults.set(cigarettesLoggedToday, forKey: Keys.cigarettesToday)
        defaults.set(todayCigaretteTimestamps, forKey: Keys.timestamps)
        defaults.set(currentStreak, forKey: Keys.currentStreak)
        defaults.set(longestStreak, forKey: Keys.longestStreak)
        defaults.set(hasCompletedDailySetup, forKey: Keys.hasCompletedSetup)
    }
    
    private func appendToHistory(date: Date, count: Int, goal: Int) {
        var history = (UserDefaults.standard.array(forKey: Keys.history) as? [[String: Any]]) ?? []
        history.append([
            "date": date,
            "count": count,
            "goal": goal
        ])
        // Keep last 365 days
        if history.count > 365 { history.removeFirst(history.count - 365) }
        UserDefaults.standard.set(history, forKey: Keys.history)
    }
    
    // MARK: Keys
    
    private enum Keys {
        static let dailyGoal = "habit_dailyGoal"
        static let cigarettesToday = "habit_cigarettesToday"
        static let timestamps = "habit_timestamps"
        static let currentStreak = "habit_currentStreak"
        static let longestStreak = "habit_longestStreak"
        static let hasCompletedSetup = "habit_hasCompletedSetup"
        static let lastSetupDate = "habit_lastSetupDate"
        static let yesterdayCigarettes = "habit_yesterdayCigarettes"
        static let history = "habit_history"
    }
}
