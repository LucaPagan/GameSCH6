//
//  SettingsView.swift
//  GameSCH6
//

import SwiftUI

struct SettingsView: View {

    @ObservedObject var habitTracker = HabitTracker.shared
    @Environment(\.dismiss) var dismiss
    @AppStorage("hapticEnabled")    var hapticEnabled    = true
    @AppStorage("notifyMorning")    var notifyMorning    = true
    @AppStorage("notifyEvening")    var notifyEvening    = true
    @State private var showGoalSheet = false
    @State private var showResetAlert = false
    @State private var newGoal: Int  = HabitTracker.shared.dailyCigaretteGoal

    private let pixelFont = "Minecraft"
    private let bodyFont  = "Pixeboy-z8XGD"

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.03, blue: 0.08).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    goalSection
                    gameSection
                    notificationsSection
                    dangerSection
                    credits
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
        // Titolo nativo grande — visibile per intero, nessun troncamento
        .navigationTitle("OPTION")
        .navigationBarTitleDisplayMode(.large)
        // Nessun toolbar item: la freccia back nativa basta
        .toolbarBackground(Color(red: 0.04, green: 0.03, blue: 0.08), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showGoalSheet) { goalSheet }
        .alert("RESET STREAK", isPresented: $showResetAlert) {
            Button("Deny", role: .cancel) {}
            Button("Reset", role: .destructive) {
                UserDefaults.standard.set(0, forKey: "habit_currentStreak")
                UserDefaults.standard.set(0, forKey: "habit_longestStreak")
            }
        } message: {
            Text("Are you sure? You will lose your current streak.")
        }
    }

    // MARK: - Sezioni

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("DAILY GOAL")

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CURRENT GOAL")
                        .font(.custom(bodyFont, size: 12))
                        .foregroundColor(.white.opacity(0.40))
                    Text("\(habitTracker.dailyCigaretteGoal) CIGARETTES")
                        .font(.custom(pixelFont, size: 20))
                        .foregroundColor(Color(GameConstants.Colors.paradisoGold))
                }
                Spacer()
                pixelActionButton(label: "CHANGE") {
                    newGoal = habitTracker.dailyCigaretteGoal
                    showGoalSheet = true
                }
            }
        }
        .padding(20)
        .pixelCard()
    }

    private var gameSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("GAME")

            pixelToggle(label: "APTIC FEEDBACK",
                        detail: "Vibration at grab and events",
                        isOn: $hapticEnabled)
        }
        .padding(20)
        .pixelCard()
    }

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("NOTIFICATIONS")

            pixelToggle(label: "MORNING REMINDER",
                        detail: "At 9:00 am, set your goal",
                        isOn: $notifyMorning)
                .onChange(of: notifyMorning) { val in
                    if val { NotificationManager.shared.scheduleAllNotifications() }
                    else { NotificationManager.shared.clearAllNotifications() }
                }

            Divider().background(Color.white.opacity(0.08))

            pixelToggle(label: "EVENING REMINDER",
                        detail: "At 8:00 PM, summary of the day",
                        isOn: $notifyEvening)
        }
        .padding(20)
        .pixelCard()
    }

    private var dangerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("DANGEROUS ZONE")

            pixelActionButton(label: "RESET STREAK", destructive: true) {
                showResetAlert = true
            }
        }
        .padding(20)
        .pixelCard()
    }

    private var credits: some View {
        VStack(spacing: 6) {
            Text("AD ASTRA")
                .font(.custom(pixelFont, size: 14))
                .foregroundColor(.white.opacity(0.25))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Goal sheet

    private var goalSheet: some View {
        ZStack {
            Color(red: 0.04, green: 0.03, blue: 0.08).ignoresSafeArea()
            VStack(spacing: 28) {
                Text("NEW GOAL")
                    .font(.custom(pixelFont, size: 26))
                    .foregroundColor(Color(GameConstants.Colors.paradisoGold))
                    .padding(.top, 32)

                HStack(spacing: 28) {
                    goalSheetButton(label: "−") {
                        if newGoal > 0 { newGoal -= 1 }
                    }
                    Text("\(newGoal)")
                        .font(.custom(pixelFont, size: 64))
                        .foregroundColor(.white)
                        .frame(width: 110)
                    goalSheetButton(label: "+") {
                        if newGoal < 40 { newGoal += 1 }
                    }
                }

                Button {
                    habitTracker.completeDailySetup(goal: newGoal)
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    showGoalSheet = false
                } label: {
                    Text("SAVE")
                        .font(.custom(pixelFont, size: 22))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color(GameConstants.Colors.paradisoGold))
                        .overlay(Rectangle().stroke(Color.black.opacity(0.3), lineWidth: 3))
                }
                .padding(.horizontal, 28)

                Spacer()
            }
        }
        .presentationDetents([.medium])
    }

    private func goalSheetButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: { action(); UIImpactFeedbackGenerator(style: .light).impactOccurred() }) {
            Text(label)
                .font(.custom(pixelFont, size: 36))
                .foregroundColor(.white)
                .frame(width: 52, height: 52)
                .background(Color.white.opacity(0.10))
                .overlay(Rectangle().stroke(Color.white.opacity(0.20), lineWidth: 2))
        }
    }

    // MARK: - Componenti

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.custom(bodyFont, size: 14))
            .foregroundColor(.white.opacity(0.65))
    }

    private func pixelToggle(label: String, detail: String,
                              isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.custom(bodyFont, size: 15))
                    .foregroundColor(.white)
                Text(detail)
                    .font(.custom(bodyFont, size: 11))
                    .foregroundColor(.white.opacity(0.35))
            }
            Spacer()
            Button {
                isOn.wrappedValue.toggle()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                ZStack {
                    Rectangle()
                        .fill(isOn.wrappedValue
                              ? Color(GameConstants.Colors.paradisoGold)
                              : Color.white.opacity(0.10))
                        .frame(width: 44, height: 24)
                        .overlay(Rectangle().stroke(Color.white.opacity(0.20), lineWidth: 2))
                    Circle()
                        .fill(.white)
                        .frame(width: 16, height: 16)
                        .offset(x: isOn.wrappedValue ? 10 : -10)
                        .animation(.easeInOut(duration: 0.15), value: isOn.wrappedValue)
                }
            }
        }
    }

    private func pixelActionButton(label: String,
                                    destructive: Bool = false,
                                    action: @escaping () -> Void) -> some View {
        Button(action: { action(); UIImpactFeedbackGenerator(style: .medium).impactOccurred() }) {
            Text(label)
                .font(.custom(bodyFont, size: 15))
                .foregroundColor(destructive
                                 ? Color(GameConstants.Colors.infernoAccent)
                                 : Color(GameConstants.Colors.paradisoGold))
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(Color.white.opacity(0.06))
                .overlay(Rectangle().stroke(
                    destructive
                    ? Color(GameConstants.Colors.infernoAccent).opacity(0.4)
                    : Color.white.opacity(0.12),
                    lineWidth: 2))
        }
    }
}
