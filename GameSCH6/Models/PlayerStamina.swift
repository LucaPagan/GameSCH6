import Foundation
import Combine
import CoreGraphics

// MARK: - Player Stamina (The Mirror Logic for Pendulum)

/// Model that translates the number of cigarettes smoked into PHYSICAL MALUSES within the game.
final class PlayerStamina: ObservableObject {
    
    @Published private(set) var cigarettesLoggedToday: Int = 0
    @Published var currentStamina: CGFloat = 100.0
    lazy var lungHealth = LungHealthSystem()

    
    let maxStamina: CGFloat = 100.0
    
    init(cigarettesLoggedToday: Int = 0) {
        self.cigarettesLoggedToday = cigarettesLoggedToday
        self.currentStamina = 100.0
    }
    
    /// Updates the system every frame
    func updateLungHealth(deltaTime: TimeInterval) {
        lungHealth.update(cigarettes: cigarettesLoggedToday,
                          deltaTime: CGFloat(deltaTime))
    }
    
    /// Regenerates stamina over time
    func regenerate(deltaTime: TimeInterval) {
        let regenRate: CGFloat = 5.0 // 5% per second
        currentStamina = min(maxStamina, currentStamina + regenRate * CGFloat(deltaTime))
    }
    
    /// Consumes stamina for an action
    func consume(amount: CGFloat) -> Bool {
        if currentStamina >= amount {
            currentStamina -= amount
            return true
        }
        return false
    }
    
    // MARK: - Mirror Effects (Pendulum Malus)
    
    /// Heavy Lungs: reduces jump force.
    /// The more you smoke, the shorter and heavier the jump becomes.
    var jumpForceMultiplier: CGFloat {
        let penalty = CGFloat(cigarettesLoggedToday) * 0.02
        return max(0.5, 1.0 - penalty)
    }
    
    /// Nervousness/Tachycardia: increases pendulum speed.
    /// Makes aiming (timing) extremely difficult.
    var swingSpeedMultiplier: CGFloat {
        return 1.0 + (CGFloat(cigarettesLoggedToday) * 0.15)
    }
    
    /// Tremor: adds random "jerks" to the pendulum.
    var swingJitter: CGFloat {
        return CGFloat(cigarettesLoggedToday) * 0.03
    }
    
    /// Probability of coughing per second while hanging (makes you fall).
    var coughChancePerSecond: CGFloat {
        return CGFloat(cigarettesLoggedToday) * 0
    }
    
    /// Smoky aura opacity
    var smokyAuraOpacity: CGFloat {
        guard cigarettesLoggedToday > 0 else { return 0 }
        return min(1.0, CGFloat(cigarettesLoggedToday) / 10.0)
    }
    
    // MARK: - Smoke Mirror: Weight of Progress
    
    /// Gravity multiplier: more smoke → heavier → shorter jumps
    /// "Ash Backpack" — every cigarette adds weight
    var gravityMultiplier: CGFloat {
        let extra = CGFloat(cigarettesLoggedToday) * GameConstants.SmokeMirror.gravityPerCigarette
        return min(GameConstants.SmokeMirror.maxGravityMultiplier, 1.0 + extra)
    }
    
    /// Overall smoke visual intensity (0.0 - 1.0) — used by SmokeHazeOverlay
    var smokeIntensity: CGFloat {
        return min(1.0, CGFloat(cigarettesLoggedToday) / CGFloat(GameConstants.SmokeMirror.maxVisualCigarettes))
    }
    
    /// Heartbeat interval — more smoke → faster
    var heartbeatInterval: TimeInterval {
        guard cigarettesLoggedToday > 0 else { return 0 } // 0 = no beat
        let base = GameConstants.SmokeMirror.heartbeatBaseInterval
        let minInterval = GameConstants.SmokeMirror.heartbeatMinInterval
        let t = smokeIntensity
        return base - (base - minInterval) * Double(t)
    }
    
    // MARK: - Smoke Mirror: Withdrawal
    
    /// Withdrawal intensity (0.0–1.0)
    /// Calculated based on hours since last cigarette AND habitual frequency
    var withdrawalIntensity: CGFloat {
        let tracker = HabitTracker.shared
        let yesterdayCount = tracker.yesterdayCigaretteCount
        
        // If you didn't smoke yesterday, you don't have withdrawal
        guard yesterdayCount > 0 else { return 0 }
        // If you've already smoked today, withdrawal is reduced
        if cigarettesLoggedToday > 0 { return 0 }
        
        // Hours since last cigarette
        let hoursSinceLastCig: Double
        if let lastTimestamp = tracker.todayCigaretteTimestamps.last {
            hoursSinceLastCig = Date().timeIntervalSince(lastTimestamp) / 3600.0
        } else {
            // No cigarettes today — using time since midnight
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            hoursSinceLastCig = Date().timeIntervalSince(startOfDay) / 3600.0
        }
        
        let onset = GameConstants.SmokeMirror.withdrawalOnsetHours
        guard hoursSinceLastCig > onset else { return 0 }
        
        // Intensity grows with time and habitual smoking amount
        let timeFactor = min(1.0, (hoursSinceLastCig - onset) / 6.0) // Peak at 8 hours
        let habitFactor = min(1.0, Double(yesterdayCount) / 15.0)
        return CGFloat(timeFactor * habitFactor)
    }
    
    /// Withdrawal tremor — added to the pendulum
    var withdrawalJitter: CGFloat {
        return withdrawalIntensity * GameConstants.SmokeMirror.maxWithdrawalJitter
    }
    
    /// Probability per second that hands slip (grip slip)
    var gripSlipChance: CGFloat {
        return withdrawalIntensity * GameConstants.SmokeMirror.baseGripSlipChance
    }
    
    // MARK: - Actions
    
    func logCigarette() {
        cigarettesLoggedToday += 1
    }
    
    func resetForNewDay(cigarettesToday: Int = 0) {
        cigarettesLoggedToday = cigarettesToday
    }
    
    /// FOR DEBUG ONLY: Sets the cigarette count (Syncs malus)
    func debugSetCigarettes(count: Int) {
        cigarettesLoggedToday = max(0, count)
    }
    
    var swingModulator: CGFloat {
        lungHealth.swingMultiplier
    }

    var blurIntensity: CGFloat {
        lungHealth.blurIntensity
    }

    var breathIntensity: CGFloat {
        lungHealth.breathIntensity
    }

}
