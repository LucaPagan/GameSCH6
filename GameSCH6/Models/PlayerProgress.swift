import Foundation
import Combine
import CoreGraphics

// MARK: - Player Progress

/// Traccia i progressi nel mondo di gioco, i checkpoint raggiunti e gli equipaggiamenti cosmetici.
/// Salva i dati su UserDefaults per persistenza.
final class PlayerProgress: ObservableObject {
    
    static let shared = PlayerProgress()
    
    // MARK: Published State
    
    /// Altitudine corrente (punti assoluti nel mondo)
    @Published var currentAltitude: CGFloat {
        didSet { save() }
    }
    
    /// Indice del checkpoint più alto raggiunto (0–8, corrispondente a 9 gironi)
    @Published var highestCheckpoint: Int {
        didSet { save() }
    }
    
    /// Tempo di gioco totale in secondi
    @Published var totalPlayTime: TimeInterval {
        didSet { save() }
    }
    
    /// Cosmetici equipaggiati
    @Published var equippedHat: String? {
        didSet { save() }
    }
    
    @Published var equippedTrail: String? {
        didSet { save() }
    }
    
    @Published var characterGender: CharacterGender {
        didSet { save() }
    }
    
    // MARK: Computed
    
    /// Altitudine corrente normalizzata (da 0.0 a 1.0)
    var normalizedAltitude: CGFloat {
        return min(1.0, max(0.0, currentAltitude / GameConstants.World.totalWorldHeight))
    }
    
    /// Regno corrente basato sull'altitudine
    var currentKingdom: Kingdom {
        let norm = normalizedAltitude
        if norm < GameConstants.Kingdoms.infernoEnd { return .inferno }
        if norm < GameConstants.Kingdoms.purgatorioEnd { return .purgatorio }
        return .paradiso
    }
    
    /// Indice del girone corrente (0–2) basato sull'altitudine per la UI
    var currentGirone: Int {
        let norm = normalizedAltitude
        if norm < GameConstants.Kingdoms.infernoEnd { return 0 }
        if norm < GameConstants.Kingdoms.purgatorioEnd { return 1 }
        return 2
    }
    
    /// Nome del girone per la UI
    var gironeName: String {
            let names = ["L'Abisso di Cenere", "La Nebbia del Purgatorio", "La Vetta Pura"]
            return names[safe: currentGirone] ?? "Unknown"
        }
    
    /// Altitudine del checkpoint più alto in punti assoluti
    var highestCheckpointAltitude: CGFloat {
        let altitudes = GameConstants.Kingdoms.checkpointAltitudes
        guard highestCheckpoint < altitudes.count else { return 0 }
        return altitudes[highestCheckpoint] * GameConstants.World.totalWorldHeight
    }
    
    // MARK: Initialization
    
    init() {
        let defaults = UserDefaults.standard
        self.currentAltitude = CGFloat(defaults.float(forKey: Keys.altitude))
        self.highestCheckpoint = defaults.integer(forKey: Keys.checkpoint)
        self.totalPlayTime = defaults.double(forKey: Keys.playTime)
        self.equippedHat = defaults.string(forKey: Keys.hat)
        self.equippedTrail = defaults.string(forKey: Keys.trail)
        self.characterGender = CharacterGender(rawValue: defaults.string(forKey: Keys.gender) ?? "male") ?? .male
    }
    
    // MARK: Actions
    
    /// Aggiorna l'altitudine. Lancia una notifica se si raggiunge un nuovo checkpoint.
    func updateAltitude(_ newAltitude: CGFloat) {
        currentAltitude = max(currentAltitude, newAltitude)
        
        let altitudes = GameConstants.Kingdoms.checkpointAltitudes
        var cpIndex = 0
        for (i, threshold) in altitudes.enumerated() {
            if normalizedAltitude >= threshold {
                cpIndex = i
            }
        }
        
        if cpIndex > highestCheckpoint {
            highestCheckpoint = cpIndex
            NotificationCenter.default.post(
                name: .checkpointReached,
                object: nil,
                userInfo: ["girone": currentGirone, "name": gironeName]
            )
        }
    }
    
    /// SOLO PER DEBUG: Imposta forzatamente il checkpoint per il teletrasporto
    func debugSetCheckpoint(index: Int) {
        let altitudes = GameConstants.Kingdoms.checkpointAltitudes
        guard index >= 0 && index < altitudes.count else { return }
        
        highestCheckpoint = index
        currentAltitude = altitudes[index] * GameConstants.World.totalWorldHeight
        save()
    }
    
    /// Triggerato dalla fisica (contatto con il marker del checkpoint)
    func reachCheckpoint(at altitude: CGFloat) {
        updateAltitude(altitude)
    }
    
    /// Reset all'ultimo checkpoint (Usato dalla Midnight Reset Cutscene se l'utente fuma troppo)
    func resetToLastCheckpoint() {
        currentAltitude = highestCheckpointAltitude
    }
    
    func addPlayTime(_ seconds: TimeInterval) {
        totalPlayTime += seconds
    }
    
    func fullReset() {
        currentAltitude = 0
        highestCheckpoint = 0
        totalPlayTime = 0
        equippedHat = nil
        equippedTrail = nil
        characterGender = .male
        save()
    }
    
    // MARK: Persistence
    
    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(Float(currentAltitude), forKey: Keys.altitude)
        defaults.set(highestCheckpoint, forKey: Keys.checkpoint)
        defaults.set(totalPlayTime, forKey: Keys.playTime)
        defaults.set(equippedHat, forKey: Keys.hat)
        defaults.set(equippedTrail, forKey: Keys.trail)
        defaults.set(characterGender.rawValue, forKey: Keys.gender)
    }
    
    private enum Keys {
        static let altitude = "progress_altitude"
        static let checkpoint = "progress_checkpoint"
        static let playTime = "progress_playTime"
        static let hat = "progress_hat"
        static let trail = "progress_trail"
        static let gender = "progress_gender"
    }
}

// MARK: - Supporting Types

enum Kingdom: String, CaseIterable {
    case inferno
    case purgatorio
    case paradiso
    
    var displayName: String {
        rawValue.capitalized
    }
}

enum CharacterGender: String, CaseIterable {
    case male
    case female
}

// MARK: - Notification

extension Notification.Name {
    static let checkpointReached = Notification.Name("checkpointReached")
    static let midnightReset = Notification.Name("midnightReset")
}

// MARK: - Safe Array Access

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
