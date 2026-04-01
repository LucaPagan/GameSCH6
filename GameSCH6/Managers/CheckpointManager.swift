import SpriteKit

// MARK: - Checkpoint Manager

/// Gestisce la logica di salvataggio e ripristino dei checkpoint.
/// I checkpoint sono permanenti — il giocatore non cade mai al di sotto di essi una volta raggiunti.
class CheckpointManager {
    
    private let progress = PlayerProgress.shared
    
    /// Controlla se il giocatore ha raggiunto un nuovo checkpoint all'altitudine data.
    /// Ritorna il nome del girone se è stato raggiunto un nuovo checkpoint.
    func checkAndSave(altitude: CGFloat) -> String? {
        // FIX: Aggiornato GameConstants.Kingdoms a GameConstants.World
        let normalized = altitude / GameConstants.World.totalWorldHeight
        let checkpoints = GameConstants.Kingdoms.checkpointAltitudes
        
        let names = [
            "Denial", "Habit", "Addiction",
            "Withdrawal", "Struggle", "Clarity",
            "Breath", "Freedom", "The Stars"
        ]
        
        for (i, threshold) in checkpoints.enumerated().reversed() {
            if normalized >= threshold && i > progress.highestCheckpoint {
                progress.highestCheckpoint = i
                return names[safe: i]
            }
        }
        
        return nil
    }
    
    /// Ottiene l'altitudine a cui resettare (ultimo checkpoint permanente)
    var resetAltitude: CGFloat {
        return progress.highestCheckpointAltitude
    }
}
