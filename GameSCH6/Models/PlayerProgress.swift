import Foundation
import Combine
import CoreGraphics

// MARK: - Player Progress

final class PlayerProgress: ObservableObject {
    
    static let shared = PlayerProgress()
    
    // MARK: Published State
    
    @Published var currentAltitude: CGFloat {
        didSet { save() }
    }
    
    @Published var highestCheckpoint: Int {
        didSet { save() }
    }
    
    @Published var totalPlayTime: TimeInterval {
        didSet { save() }
    }
    
    @Published var equippedHat: String? {
        didSet { save() }
    }
    
    @Published var equippedTrail: String? {
        didSet { save() }
    }
    
    @Published var characterGender: CharacterGender {
        didSet { save() }
    }
    
    // MARK: - Session Save State
    // Saved when the player pauses or closes the app.
    // Automatically restored when resuming from the main menu.
    
    /// true = there is a saved session to resume
    var hasSavedSession: Bool {
        UserDefaults.standard.bool(forKey: Keys.hasSavedSession)
    }
    
    /// Saved stamina (0–100)
    var savedStamina: CGFloat {
        CGFloat(UserDefaults.standard.float(forKey: Keys.savedStamina))
    }
    
    /// Saved session cigarettes
    var savedCigarettes: Int {
        UserDefaults.standard.integer(forKey: Keys.savedCigarettes)
    }
    
    // MARK: Computed
    
    var normalizedAltitude: CGFloat {
        return min(1.0, max(0.0, currentAltitude / GameConstants.World.totalWorldHeight))
    }
    
    var currentKingdom: Kingdom {
        let norm = normalizedAltitude
        if norm < GameConstants.Kingdoms.infernoEnd { return .inferno }
        if norm < GameConstants.Kingdoms.purgatorioEnd { return .purgatorio }
        return .paradiso
    }
    
    var currentGirone: Int {
        let norm = normalizedAltitude
        if norm < GameConstants.Kingdoms.infernoEnd { return 0 }
        if norm < GameConstants.Kingdoms.purgatorioEnd { return 1 }
        return 2
    }
    
    var gironeName: String {
        let names = ["The Ash Abyss", "The Purgatory Mist", "The Pure Peak"]
        return names[safe: currentGirone] ?? "Unknown"
    }
    
    var highestCheckpointAltitude: CGFloat {
        let altitudes = GameConstants.Kingdoms.checkpointAltitudes
        guard highestCheckpoint < altitudes.count else { return 0 }
        return altitudes[highestCheckpoint] * GameConstants.World.totalWorldHeight
    }
    
    // MARK: Initialization
    
    init() {
        let defaults = UserDefaults.standard
        self.currentAltitude   = CGFloat(defaults.float(forKey: Keys.altitude))
        self.highestCheckpoint = defaults.integer(forKey: Keys.checkpoint)
        self.totalPlayTime     = defaults.double(forKey: Keys.playTime)
        self.equippedHat       = defaults.string(forKey: Keys.hat)
        self.equippedTrail     = defaults.string(forKey: Keys.trail)
        self.characterGender   = CharacterGender(
            rawValue: defaults.string(forKey: Keys.gender) ?? "male") ?? .male
    }
    
    // MARK: Actions
    
    func updateAltitude(_ newAltitude: CGFloat) {
        currentAltitude = max(currentAltitude, newAltitude)
        
        let altitudes = GameConstants.Kingdoms.checkpointAltitudes
        var cpIndex = 0
        for (i, threshold) in altitudes.enumerated() {
            if normalizedAltitude >= threshold { cpIndex = i }
        }
        
        if cpIndex > highestCheckpoint {
            highestCheckpoint = cpIndex
            NotificationCenter.default.post(
                name: .checkpointReached, object: nil,
                userInfo: ["girone": currentGirone, "name": gironeName])
        }
    }
    
    func debugSetCheckpoint(index: Int) {
        let altitudes = GameConstants.Kingdoms.checkpointAltitudes
        guard index >= 0 && index < altitudes.count else { return }
        highestCheckpoint = index
        currentAltitude   = altitudes[index] * GameConstants.World.totalWorldHeight
        save()
    }
    
    func reachCheckpoint(at altitude: CGFloat) {
        updateAltitude(altitude)
    }
    
    func resetToLastCheckpoint() {
        currentAltitude = highestCheckpointAltitude
    }
    
    func addPlayTime(_ seconds: TimeInterval) {
        totalPlayTime += seconds
    }
    
    // MARK: - Session Save / Restore
    
    /// Saves the complete state of the current session.
    /// Called from the pause menu and from applicationWillResignActive.
    func saveSession(stamina: CGFloat, cigarettes: Int) {
        let defaults = UserDefaults.standard
        defaults.set(true,             forKey: Keys.hasSavedSession)
        defaults.set(Float(stamina),   forKey: Keys.savedStamina)
        defaults.set(cigarettes,       forKey: Keys.savedCigarettes)
        // altitude and checkpoint are already saved automatically via didSet
        save()
    }
    
    /// Clears the saved session.
    /// Called when the player performs a Restart or reaches the end.
    func clearSavedSession() {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: Keys.hasSavedSession)
        defaults.removeObject(forKey: Keys.savedStamina)
        defaults.removeObject(forKey: Keys.savedCigarettes)
    }
    
    // MARK: - Full Reset
    
    /// Full reset — used by Restart.
    func fullReset() {
        clearSavedSession()
        currentAltitude    = 0
        highestCheckpoint  = 0
        totalPlayTime      = 0
        equippedHat        = nil
        equippedTrail      = nil
        characterGender    = .male
        save()
    }
    
    // MARK: Persistence
    
    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(Float(currentAltitude), forKey: Keys.altitude)
        defaults.set(highestCheckpoint,      forKey: Keys.checkpoint)
        defaults.set(totalPlayTime,          forKey: Keys.playTime)
        defaults.set(equippedHat,            forKey: Keys.hat)
        defaults.set(equippedTrail,          forKey: Keys.trail)
        defaults.set(characterGender.rawValue, forKey: Keys.gender)
    }
    
    private enum Keys {
        static let altitude          = "progress_altitude"
        static let checkpoint        = "progress_checkpoint"
        static let playTime          = "progress_playTime"
        static let hat               = "progress_hat"
        static let trail             = "progress_trail"
        static let gender            = "progress_gender"
        // Session
        static let hasSavedSession   = "progress_hasSavedSession"
        static let savedStamina      = "progress_savedStamina"
        static let savedCigarettes   = "progress_savedCigarettes"
    }
}

// MARK: - Supporting Types

enum Kingdom: String, CaseIterable {
    case inferno, purgatorio, paradiso
    var displayName: String { rawValue.capitalized }
}

enum CharacterGender: String, CaseIterable {
    case male, female
}

extension Notification.Name {
    static let checkpointReached = Notification.Name("checkpointReached")
    static let midnightReset     = Notification.Name("midnightReset")
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
