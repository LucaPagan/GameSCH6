import SwiftUI

// MARK: - Habit Setup View
//
// Appare la prima volta e quando si resetta il goal dalle opzioni.
// Stile pixel art coerente con il gioco.

struct HabitSetupView: View {

    @ObservedObject var habitTracker: HabitTracker
    var onComplete: () -> Void

    @State private var goal: Int
    @State private var showConfirm = false

    private let pixelFont = "Minecraft"
    private let bodyFont  = "Pixeboy-z8XGD"

    init(habitTracker: HabitTracker, onComplete: @escaping () -> Void) {
        self.habitTracker = habitTracker
        self.onComplete   = onComplete
        _goal = State(initialValue: max(1, habitTracker.dailyCigaretteGoal))
    }

    var body: some View {
        ZStack {
            // ── Background ──
            Color(red: 0.04, green: 0.03, blue: 0.08).ignoresSafeArea()
            pixelStarField

            VStack(spacing: 0) {
                Spacer()

                // ── Header ──
                VStack(spacing: 8) {
                    Text("☀️")
                        .font(.system(size: 40))

                    Text("NUOVO GIORNO")
                        .font(.custom(pixelFont, size: 30))
                        .foregroundColor(Color(GameConstants.Colors.paradisoGold))
                        .shadow(color: .black, radius: 0, x: 2, y: -2)

                    if habitTracker.yesterdayCigaretteCount > 0 {
                        Text("IERI: \(habitTracker.yesterdayCigaretteCount) SIGARETTE")
                            .font(.custom(bodyFont, size: 18))
                            .foregroundColor(.white.opacity(0.55))
                    }
                }

                Spacer().frame(height: 36)

                // ── Goal setter ──
                VStack(spacing: 20) {
                    Text("QUANTE VUOI FUMARNE AL GIORNO?")
                        .font(.custom(bodyFont, size: 17))
                        .foregroundColor(.white.opacity(0.80))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // Numero grande
                    HStack(spacing: 28) {
                        pixelButton(label: "−") {
                            if goal > 0 { goal -= 1 }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }

                        VStack(spacing: 4) {
                            Text("\(goal)")
                                .font(.custom(pixelFont, size: 72))
                                .foregroundColor(colorForGoal(goal))
                                .animation(.easeInOut(duration: 0.1), value: goal)

                            Text("AL GIORNO")
                                .font(.custom(bodyFont, size: 14))
                                .foregroundColor(.white.opacity(0.35))
                        }
                        .frame(width: 120)

                        pixelButton(label: "+") {
                            if goal < 40 { goal += 1 }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }

                    // Preset rapidi
                    HStack(spacing: 10) {
                        ForEach([0, 5, 10, 20], id: \.self) { preset in
                            Button {
                                goal = preset
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Text("\(preset)")
                                    .font(.custom(bodyFont, size: 16))
                                    .foregroundColor(goal == preset ? .black : .white.opacity(0.7))
                                    .frame(width: 52, height: 32)
                                    .background(
                                        goal == preset
                                        ? Color(GameConstants.Colors.paradisoGold)
                                        : Color.white.opacity(0.08)
                                    )
                                    .overlay(Rectangle().stroke(Color.white.opacity(0.15), lineWidth: 2))
                            }
                        }
                    }

                    // Descrizione contestuale
                    Text(goalDescription(goal))
                        .font(.custom(bodyFont, size: 14))
                        .foregroundColor(colorForGoal(goal).opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .animation(.easeInOut, value: goal)
                }
                .padding(24)
                .background(
                    ZStack {
                        Color(red: 0.06, green: 0.04, blue: 0.10)
                        Rectangle()
                            .stroke(Color(GameConstants.Colors.infernoAccent).opacity(0.4),
                                    lineWidth: 3)
                    }
                )
                .padding(.horizontal, 20)

                Spacer().frame(height: 32)

                // ── CTA ──
                Button {
                    habitTracker.completeDailySetup(goal: goal)
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    onComplete()
                    NotificationCenter.default.post(name: Notification.Name("startGameAutomatically"), object: nil)
                } label: {
                    Text("INIZIA L'ASCESA  ▲")
                        .font(.custom(pixelFont, size: 22))
                        .foregroundColor(Color(red: 0.06, green: 0.04, blue: 0.00))
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(Color(GameConstants.Colors.paradisoGold))
                        .overlay(Rectangle().stroke(Color.black.opacity(0.3), lineWidth: 3))
                        .shadow(color: .black.opacity(0.4), radius: 0, x: 3, y: -3)
                }
                .padding(.horizontal, 20)

                // Nota se goal = 0
                if goal == 0 {
                    Text("Obiettivo zero = massima salute in gioco.")
                        .font(.custom(bodyFont, size: 13))
                        .foregroundColor(.white.opacity(0.30))
                        .padding(.top, 8)
                }

                Spacer().frame(height: 40)
            }
        }
    }

    // MARK: - Sottoviste

    @ViewBuilder
    private var pixelStarField: some View {
        GeometryReader { geo in
            ForEach(0..<40, id: \.self) { i in
                let x = CGFloat((i * 137) % Int(geo.size.width))
                let y = CGFloat((i * 97)  % Int(geo.size.height))
                let s = CGFloat.random(in: 1.5...3.5)
                Rectangle()
                    .fill(Color.white.opacity(Double.random(in: 0.1...0.5)))
                    .frame(width: s, height: s)
                    .position(x: x, y: y)
            }
        }
        .ignoresSafeArea()
    }

    private func pixelButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.custom(pixelFont, size: 36))
                .foregroundColor(.white)
                .frame(width: 52, height: 52)
                .background(Color.white.opacity(0.10))
                .overlay(Rectangle().stroke(Color.white.opacity(0.20), lineWidth: 2))
        }
    }

    // MARK: - Helpers

    private func colorForGoal(_ g: Int) -> Color {
        if g == 0  { return Color(GameConstants.Colors.paradisoGreen) }
        if g <= 5  { return Color(GameConstants.Colors.paradisoGreen) }
        if g <= 12 { return Color(GameConstants.Colors.purgatorioWarm) }
        return Color(GameConstants.Colors.infernoAccent)
    }

    private func goalDescription(_ g: Int) -> String {
        switch g {
        case 0:      return "Polmoni d'acciaio. Nessun malus in gioco."
        case 1...4:  return "Ottimo obiettivo. Malus minimi."
        case 5...9:  return "Accettabile. Il pendolo sarà irregolare."
        case 10...14: return "Pericoloso. Tosse e visione compromessa."
        default:     return "Critico. Sopravvivenza difficile."
        }
    }
}
