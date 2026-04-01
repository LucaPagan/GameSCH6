import Foundation
import Combine
import CoreGraphics

// MARK: - Player Stamina (The Mirror Logic for Pendulum)

/// Modello che traduce il numero di sigarette fumate in MALUS FISICI all'interno del gioco.
final class PlayerStamina: ObservableObject {
    
    @Published private(set) var cigarettesLoggedToday: Int = 0
    @Published var currentStamina: CGFloat = 100.0
    
    let maxStamina: CGFloat = 100.0
    
    init(cigarettesLoggedToday: Int = 0) {
        self.cigarettesLoggedToday = cigarettesLoggedToday
        self.currentStamina = 100.0
    }
    
    /// Rigenera la stamina nel tempo
    func regenerate(deltaTime: TimeInterval) {
        let regenRate: CGFloat = 5.0 // 5% al secondo
        currentStamina = min(maxStamina, currentStamina + regenRate * CGFloat(deltaTime))
    }
    
    /// Consuma stamina per un'azione
    func consume(amount: CGFloat) -> Bool {
        if currentStamina >= amount {
            currentStamina -= amount
            return true
        }
        return false
    }
    
    // MARK: - Mirror Effects (Pendulum Malus)
    
    /// Polmoni Pesanti: riduce la forza del salto.
    /// Più fumi, più il salto diventa corto e pesante.
    var jumpForceMultiplier: CGFloat {
        let penalty = CGFloat(cigarettesLoggedToday) * 0.02
        return max(0.5, 1.0 - penalty)
    }
    
    /// Nervosismo/Tachicardia: aumenta la velocità del pendolo.
    /// Rende difficilissimo prendere la mira (il tempismo).
    var swingSpeedMultiplier: CGFloat {
        return 1.0 + (CGFloat(cigarettesLoggedToday) * 0.15)
    }
    
    /// Tremore: aggiunge "scatti" casuali al pendolo.
    var swingJitter: CGFloat {
        return CGFloat(cigarettesLoggedToday) * 0.03
    }
    
    /// Probabilità di tossire al secondo mentre sei appeso (ti fa cadere).
    var coughChancePerSecond: CGFloat {
        return CGFloat(cigarettesLoggedToday) * 0.015
    }
    
    /// Opacità dell'aura di fumo
    var smokyAuraOpacity: CGFloat {
        guard cigarettesLoggedToday > 0 else { return 0 }
        return min(1.0, CGFloat(cigarettesLoggedToday) / 10.0)
    }
    
    // MARK: - Actions
    
    func logCigarette() {
        cigarettesLoggedToday += 1
    }
    
    func resetForNewDay(cigarettesToday: Int = 0) {
        cigarettesLoggedToday = cigarettesToday
    }
    
    /// SOLO PER DEBUG: Imposta il conteggio sigarette (Sincronizza malus)
    func debugSetCigarettes(count: Int) {
        cigarettesLoggedToday = max(0, count)
    }
}
