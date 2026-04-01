import SwiftUI

// MARK: - Habit Setup View

/// Shown once per day before gameplay begins.
/// User sets their Daily Cigarette Goal.
struct HabitSetupView: View {
    
    @ObservedObject var habitTracker: HabitTracker
    var onComplete: () -> Void
    
    @State private var goal: Int
    
    init(habitTracker: HabitTracker, onComplete: @escaping () -> Void) {
        self.habitTracker = habitTracker
        self.onComplete = onComplete
        _goal = State(initialValue: habitTracker.dailyCigaretteGoal)
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(red: 0.05, green: 0.05, blue: 0.05)
                .ignoresSafeArea()
            
            VStack(spacing: 28) {
                Spacer()
                
                // Greeting
                Text("☀️")
                    .font(.system(size: 48))
                
                Text("Good Morning!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                // Yesterday's stats
                if habitTracker.yesterdayCigaretteCount > 0 {
                    Text("Yesterday: \(habitTracker.yesterdayCigaretteCount) cigarettes")
                        .font(.system(size: 16, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                // Streak
                if habitTracker.currentStreak > 0 {
                    HStack(spacing: 6) {
                        Text("🔥")
                        Text("\(habitTracker.currentStreak) day streak")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                    }
                }
                
                Spacer()
                
                // Goal setter
                VStack(spacing: 16) {
                    Text("Today's Goal:")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                    
                    HStack(spacing: 24) {
                        // Minus button
                        Button(action: {
                            if goal > 0 { goal -= 1 }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        // Goal number
                        Text("\(goal)")
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(width: 100)
                        
                        // Plus button
                        Button(action: {
                            if goal < 40 { goal += 1 }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    
                    Text("max cigarettes")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(28)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 24)
                
                // Stamina preview
                staminaPreview
                
                Spacer()
                
                // CTA Button
                Button(action: {
                    habitTracker.completeDailySetup(goal: goal)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onComplete()
                }) {
                    Text("BEGIN ASCENT ▲")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.84, blue: 0.0),
                                    Color(red: 1.0, green: 0.65, blue: 0.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - Stamina Preview
    
    private var staminaPreview: some View {
        VStack(spacing: 6) {
            HStack {
                Text("💪")
                Text("Max stamina starts at 100%!")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(Color(red: 0.18, green: 0.80, blue: 0.44))
            }
            
            if goal > 0 {
                Text("Each cigarette reduces it by 5%")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }
}

// MARK: - Profile View

/// Displays player stats: altitude, girone, streak, and smoking history.
struct ProfileView: View {
    
    @ObservedObject var progress = PlayerProgress.shared
    @ObservedObject var habitTracker = HabitTracker.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.05)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Character preview
                        characterCard
                        
                        // Stats grid
                        statsGrid
                        
                        // Streak rewards
                        streakRewardsSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                }
            }
        }
    }
    
    // MARK: - Character Card
    
    private var characterCard: some View {
        VStack(spacing: 12) {
            // Placeholder character
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.3))
                .frame(width: 80, height: 120)
                .overlay(
                    Text("🧗")
                        .font(.system(size: 48))
                )
            
            Text(progress.currentKingdom.displayName)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("Girone: \(progress.gironeName)")
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.06))
        )
    }
    
    // MARK: - Stats Grid
    
    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            statCell(icon: "↑", value: "\(Int(progress.currentAltitude / 10))m", label: "Altitude")
            statCell(icon: "🔥", value: "\(habitTracker.currentStreak)", label: "Streak")
            statCell(icon: "⏱", value: formatTime(progress.totalPlayTime), label: "Play Time")
            statCell(icon: "🏁", value: "\(progress.highestCheckpoint + 1)/9", label: "Checkpoints")
        }
    }
    
    private func statCell(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Text(icon)
                .font(.system(size: 24))
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
        )
    }
    
    // MARK: - Streak Rewards
    
    private var streakRewardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Streak Rewards")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            ForEach(HabitTracker.streakMilestones, id: \.self) { milestone in
                let achieved = habitTracker.longestStreak >= milestone
                
                HStack {
                    Image(systemName: achieved ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(achieved
                            ? Color(red: 0.18, green: 0.80, blue: 0.44)
                            : .white.opacity(0.3))
                    
                    Text("\(milestone) days")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(achieved ? .white : .white.opacity(0.4))
                    
                    Spacer()
                    
                    Text(rewardName(for: milestone))
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(achieved
                            ? Color(red: 1.0, green: 0.84, blue: 0.0)
                            : .white.opacity(0.3))
                }
                .padding(.vertical, 4)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.04))
        )
    }
    
    // MARK: - Helpers
    
    private func rewardName(for days: Int) -> String {
        switch days {
        case 3:   return "Silver Trail"
        case 7:   return "Golden Trail"
        case 14:  return "Phoenix Hat"
        case 30:  return "Star Aura"
        case 60:  return "Crystal Wings"
        case 90:  return "Aurora Crown"
        case 180: return "Nebula Trail"
        case 365: return "Celestial Form"
        default:  return "Mystery"
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let mins = Int(seconds) % 3600 / 60
        return "\(hours)h \(mins)m"
    }
}
