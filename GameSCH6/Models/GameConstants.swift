import CoreGraphics
import SpriteKit

// MARK: - Game Constants

enum GameConstants {

    // MARK: - Swing (fisica rotazione Rocky Climb)
    enum Swing {
        /// Lunghezza del braccio player-pietra in punti.
        /// A 30.0 il player ruota aderente alla pietra (mani attaccate)
        static let armLength: CGFloat = 30.0

        /// Velocità angolare base in radianti/secondo (senso antiorario positivo).
        /// 2π = un giro completo al secondo. 2.2 = ~1 giro ogni 2.8 secondi.
        static let baseAngularVelocity: CGFloat = 2.2

        /// Ogni quanto secondi viene aggiornata la perturbazione del fumo
        static let smokeNoisePeriod: TimeInterval = 0.3

        /// Perturbazione angolare aggiunta per ogni sigaretta fumata
        static let smokePerturbationPerCig: CGFloat = 0.08
    }

    // MARK: - Jump (mantenuto per retrocompatibilità con TrajectoryDotsNode)
    enum Jump {
        static let baseForce: CGFloat = 450.0
        static let baseSwingSpeed: CGFloat = 2.5
        static let maxSwingAngle: CGFloat = .pi / 2.5
    }

    // MARK: - Mirror (malus fumo sul gameplay)
    enum Mirror {
        static let maxCigarettesThreshold: Int = 20
        static let baseChargeDuration: TimeInterval = 0.6
        static let chargePenaltyPerCigarette: TimeInterval = 0.1
        static let baseLinearDamping: CGFloat = 4.0
        static let dampingLossPerCigarette: CGFloat = 0.15
        static let baseCoughChancePerSecond: CGFloat = 0.0
        static let coughChancePerCigarette: CGFloat = 0.015
    }

    // MARK: - World
    enum World {
        static let gravity: CGFloat = -18.0
        static let playerMass: CGFloat = 0.5
        static let totalWorldHeight: CGFloat = 50_000.0
        static let chunkSize: CGFloat = 1000.0
        static let renderDistance: Int = 2
    }

    // MARK: - Kingdoms / Checkpoints
    enum Kingdoms {
        static let infernoEnd:     CGFloat = 0.33
        static let purgatorioEnd:  CGFloat = 0.66
        
        /// Checkpoint ogni 2500m (0.05 di 50.000m) + transizioni regni
        static let checkpointAltitudes: [CGFloat] = [
            0.0, 0.05, 0.1, 0.15, 0.2, 0.25, 0.3, 0.33, 0.35, 0.4, 0.45, 0.5, 
            0.55, 0.6, 0.65, 0.66, 0.7, 0.75, 0.8, 0.85, 0.9, 0.95, 1.0
        ]
    }

    // MARK: - Physics categories
    enum Physics {
        static let player:       UInt32 = 0x1 << 0
        static let platform:     UInt32 = 0x1 << 1
        static let enemy:        UInt32 = 0x1 << 2
        static let pigeon:       UInt32 = 0x1 << 3
        static let spike:        UInt32 = 0x1 << 4
        static let checkpoint:   UInt32 = 0x1 << 5
        static let boundary:     UInt32 = 0x1 << 6
        static let hold:         UInt32 = 0x1 << 7
    }

    // MARK: - Colors
    enum Colors {
        static let infernoDark    = SKColor(red: 0.10, green: 0.10, blue: 0.18, alpha: 1.0)
        static let infernoAccent  = SKColor(red: 0.91, green: 0.27, blue: 0.38, alpha: 1.0)
        static let infernoSmoke   = SKColor(red: 0.09, green: 0.13, blue: 0.24, alpha: 1.0)
        static let purgatorioBG   = SKColor(red: 0.29, green: 0.40, blue: 0.25, alpha: 1.0)
        static let purgatorioWarm = SKColor(red: 0.83, green: 0.65, blue: 0.45, alpha: 1.0)
        static let paradisoSky    = SKColor(red: 0.53, green: 0.81, blue: 0.92, alpha: 1.0)
        static let paradisoGold   = SKColor(red: 1.00, green: 0.84, blue: 0.00, alpha: 1.0)
        static let paradisoGreen  = SKColor(red: 0.18, green: 0.80, blue: 0.44, alpha: 1.0)
        static let uiBG           = SKColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0)
        static let uiText         = SKColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1.0)
        static let hazePigeon     = SKColor(red: 0.42, green: 0.05, blue: 0.68, alpha: 1.0)
    }
}
