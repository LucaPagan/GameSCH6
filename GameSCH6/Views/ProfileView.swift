//
//  ProfileView.swift
//  GameSCH6
//

import SwiftUI

struct ProfileView: View {

    @ObservedObject var progress     = PlayerProgress.shared
    @ObservedObject var habitTracker = HabitTracker.shared
    @Environment(\.dismiss) var dismiss

    private let pixelFont = "Minecraft"
    private let bodyFont  = "Pixeboy-z8XGD"

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.03, blue: 0.08).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    header
                    smokingStats
                    gameStats
                    streakRewards
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
        // Titolo nativo grande — visibile per intero, nessun troncamento
        .navigationTitle("PROFILE")
        .navigationBarTitleDisplayMode(.large)
        // Nessun toolbar item: la freccia back nativa basta
        .toolbarBackground(Color(red: 0.04, green: 0.03, blue: 0.08), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Header con salute polmonare

    private var header: some View {
        VStack(spacing: 12) {
            pixelClimber

            let cigs    = habitTracker.cigarettesLoggedToday
            let maxCigs = 20
            let ratio   = max(0.0, 1.0 - Double(cigs) / Double(maxCigs))

            Text("PULMONARY HEALTH")
                .font(.custom(bodyFont, size: 14))
                .foregroundColor(.white.opacity(0.45))

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 10)
                    Rectangle()
                        .fill(healthColor(ratio))
                        .frame(width: geo.size.width * ratio, height: 10)
                }
            }
            .frame(height: 10)
            .overlay(Rectangle().stroke(Color.white.opacity(0.12), lineWidth: 2))

            Text("\(Int(ratio * 100))%  —  \(healthLabel(ratio))")
                .font(.custom(bodyFont, size: 16))
                .foregroundColor(healthColor(ratio))
        }
        .padding(20)
        .pixelCard()
    }

    private var pixelClimber: some View {
        HStack(spacing: 2) {
            ForEach(climberPixels(), id: \.self) { row in
                VStack(spacing: 2) {
                    ForEach(row, id: \.self) { filled in
                        Rectangle()
                            .fill(filled
                                  ? Color(GameConstants.Colors.paradisoGold)
                                  : Color.clear)
                            .frame(width: 7, height: 7)
                    }
                }
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: - Stats fumo

    private var smokingStats: some View {
        VStack(alignment: .leading, spacing: 14) {
            pixelSectionTitle("SMOKING STATS")

            HStack(spacing: 12) {
                statBlock(value: "\(habitTracker.cigarettesLoggedToday)",
                          label: "TODAY",
                          color: colorForCigs(habitTracker.cigarettesLoggedToday))
                statBlock(value: "\(habitTracker.dailyCigaretteGoal)",
                          label: "GOAL",
                          color: .white)
                statBlock(value: "\(habitTracker.yesterdayCigaretteCount)",
                          label: "YESTERDAY",
                          color: .white.opacity(0.6))
            }

            let cigs = habitTracker.cigarettesLoggedToday
            let goal = habitTracker.dailyCigaretteGoal
            if cigs > 0 || goal > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("TODAY: \(cigs) / \(goal)")
                        .font(.custom(bodyFont, size: 13))
                        .foregroundColor(.white.opacity(0.45))
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 8)
                            Rectangle()
                                .fill(colorForCigs(cigs))
                                .frame(width: goal > 0
                                       ? min(geo.size.width, geo.size.width * CGFloat(cigs) / CGFloat(goal))
                                       : 0,
                                       height: 8)
                        }
                    }
                    .frame(height: 8)
                    .overlay(Rectangle().stroke(Color.white.opacity(0.10), lineWidth: 1))
                }
            }
        }
        .padding(20)
        .pixelCard()
    }

    // MARK: - Stats gioco

    private var gameStats: some View {
        VStack(alignment: .leading, spacing: 14) {
            pixelSectionTitle("GAME STATS")

            HStack(spacing: 12) {
                statBlock(value: "\(Int(progress.currentAltitude))m",
                          label: "ALTITUDE",
                          color: Color(GameConstants.Colors.paradisoSky))
                statBlock(value: "\(progress.highestCheckpoint + 1)",
                          label: "CHECKPOINT",
                          color: Color(GameConstants.Colors.paradisoGold))
                statBlock(value: formatTime(progress.totalPlayTime),
                          label: "TIME",
                          color: .white.opacity(0.7))
            }

            HStack {
                Text("KINGDOM:")
                    .font(.custom(bodyFont, size: 13))
                    .foregroundColor(.white.opacity(0.45))
                Text(progress.currentKingdom.displayName.uppercased())
                    .font(.custom(pixelFont, size: 14))
                    .foregroundColor(kingdomColor(progress.currentKingdom))
            }
        }
        .padding(20)
        .pixelCard()
    }

    // MARK: - Streak rewards

    private var streakRewards: some View {
        VStack(alignment: .leading, spacing: 14) {
            pixelSectionTitle("🔥  STREAK: \(habitTracker.currentStreak) DAY")

            ForEach(HabitTracker.streakMilestones, id: \.self) { milestone in
                let achieved = habitTracker.longestStreak >= milestone
                HStack(spacing: 12) {
                    ZStack {
                        Rectangle()
                            .fill(achieved
                                  ? Color(GameConstants.Colors.paradisoGreen)
                                  : Color.white.opacity(0.06))
                            .frame(width: 20, height: 20)
                            .overlay(Rectangle().stroke(Color.white.opacity(0.15), lineWidth: 2))
                        if achieved {
                            Text("✓")
                                .font(.custom(pixelFont, size: 12))
                                .foregroundColor(.black)
                        }
                    }

                    Text("\(milestone) DAY")
                        .font(.custom(bodyFont, size: 15))
                        .foregroundColor(achieved ? .white : .white.opacity(0.35))

                    Spacer()

                    Text(rewardName(for: milestone).uppercased())
                        .font(.custom(bodyFont, size: 13))
                        .foregroundColor(achieved
                                         ? Color(GameConstants.Colors.paradisoGold)
                                         : .white.opacity(0.20))
                }
            }
        }
        .padding(20)
        .pixelCard()
    }

    // MARK: - Componenti riutilizzabili

    private func pixelSectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.custom(bodyFont, size: 15))
            .foregroundColor(.white.opacity(0.70))
    }

    private func statBlock(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.custom(pixelFont, size: 20))
                .foregroundColor(color)
            Text(label)
                .font(.custom(bodyFont, size: 11))
                .foregroundColor(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.05))
        .overlay(Rectangle().stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Helpers

    private func climberPixels() -> [[Bool]] {
        let rows = [
            [false,true,true,true,false],
            [false,true,true,true,false],
            [false,false,true,false,false],
            [false,true,true,true,false],
            [true,false,true,false,true],
            [true,false,false,false,true]
        ]
        return rows.map { $0 }
    }

    private func healthColor(_ ratio: Double) -> Color {
        if ratio > 0.75 { return Color(GameConstants.Colors.paradisoGreen) }
        if ratio > 0.50 { return Color(GameConstants.Colors.purgatorioWarm) }
        if ratio > 0.25 { return Color(red: 0.95, green: 0.50, blue: 0.10) }
        return Color(GameConstants.Colors.infernoAccent)
    }

    private func healthLabel(_ ratio: Double) -> String {
        if ratio > 0.75 { return "HEALTHY LUNGS" }
        if ratio > 0.50 { return "FATIGUE" }
        if ratio > 0.25 { return "BRONCHITIS" }
        return "CRITICAL CONDITIONS"
    }

    private func colorForCigs(_ cigs: Int) -> Color {
        if cigs <= 4  { return Color(GameConstants.Colors.paradisoGreen) }
        if cigs <= 9  { return Color(GameConstants.Colors.purgatorioWarm) }
        if cigs <= 14 { return Color(red: 0.95, green: 0.50, blue: 0.10) }
        return Color(GameConstants.Colors.infernoAccent)
    }

    private func kingdomColor(_ k: Kingdom) -> Color {
        switch k {
        case .inferno:    return Color(GameConstants.Colors.infernoAccent)
        case .purgatorio: return Color(GameConstants.Colors.purgatorioWarm)
        case .paradiso:   return Color(GameConstants.Colors.paradisoGold)
        }
    }

    private func formatTime(_ s: TimeInterval) -> String {
        let h = Int(s) / 3600; let m = Int(s) % 3600 / 60
        return "\(h)h\(m)m"
    }

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
}

// MARK: - PixelCard modifier

struct PixelCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(red: 0.07, green: 0.05, blue: 0.12))
            .overlay(Rectangle().stroke(Color.white.opacity(0.10), lineWidth: 2))
    }
}

extension View {
    func pixelCard() -> some View {
        modifier(PixelCardModifier())
    }
}
