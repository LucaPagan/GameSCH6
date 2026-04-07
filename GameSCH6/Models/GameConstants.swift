import CoreGraphics
import SpriteKit

// MARK: - Game Constants

enum GameConstants {

    // MARK: - Swing (Physics for Rocky Climb rotation)
    enum Swing {
        /// Length of the player-stone arm in points.
        /// At 30.0 the player rotates close to the stone (hands attached)
        static let armLength: CGFloat = 52.0

        /// Base angular velocity in radians/second (positive counter-clockwise).
        /// 2π = one full rotation per second. 2.2 = ~1 rotation every 2.8 seconds.
        static let baseAngularVelocity: CGFloat = 2.2

        /// How often (in seconds) the smoke perturbation is updated
        static let smokeNoisePeriod: TimeInterval = 0.3

        /// Angular perturbation added for each cigarette smoked
        static let smokePerturbationPerCig: CGFloat = 0.08
    }

    // MARK: - Jump (Maintained for backward compatibility with TrajectoryDotsNode)
    enum Jump {
        static let baseForce: CGFloat = 450.0
        static let baseSwingSpeed: CGFloat = 2.5
        static let maxSwingAngle: CGFloat = .pi / 2.5
    }

    // MARK: - Mirror (Smoke penalty on gameplay)
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
        
        /// Checkpoint every 2500m (0.05 of 50,000m) + kingdom transitions
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
        static let hazardZone:   UInt32 = 0x1 << 8  // Toxic Clouds — no knockback, only area effects
    }

    // MARK: - Smoke Mirror (Smoke Mirror System)
    enum SmokeMirror {
        // ── Haze / Visual ──
        /// Max alpha of the gray vignette (at 20+ cigarettes)
        static let maxHazeAlpha: CGFloat = 0.35
        /// Max alpha of the world desaturation
        static let maxDesaturationAlpha: CGFloat = 0.30
        /// Cigarettes to reach maximum visual effect
        static let maxVisualCigarettes: Int = 20
        
        // ── Heartbeat ──
        /// Base heartbeat interval (seconds) at 0 cigarettes (no beat)
        static let heartbeatBaseInterval: TimeInterval = 2.0
        /// Minimum interval at max cigarettes
        static let heartbeatMinInterval: TimeInterval = 0.6
        /// Vignette pulsation intensity
        static let heartbeatPulseIntensity: CGFloat = 0.08
        
        // ── Gravity / Backpack ──
        /// Additional gravity multiplier per cigarette
        static let gravityPerCigarette: CGFloat = 0.03
        /// Maximum gravity multiplier
        static let maxGravityMultiplier: CGFloat = 1.6
        
        // ── Withdrawal (Astinenza) ──
        /// Hours since last cigarette to consider "in withdrawal"
        static let withdrawalOnsetHours: Double = 2.0
        /// Maximum jitter for withdrawal (rad/s)
        static let maxWithdrawalJitter: CGFloat = 0.6
        /// Base probability of gripSlip per second during withdrawal
        static let baseGripSlipChance: CGFloat = 0.03
        
        // ── TarHound ──
        /// Cigarette threshold to activate the TarHound (0 = dormant)
        static let tarHoundActivationThreshold: Int = 1
        /// Base speed of the hound
        static let tarHoundBaseSpeed: CGFloat = 60.0
        /// Max speed (at 20 cigarettes)
        static let tarHoundMaxSpeed: CGFloat = 150.0
        
        // ── Toxic Cloud ──
        /// Stamina drain per second inside the cloud for smokers
        static let toxicCloudStaminaDrain: CGFloat = 10.0
        /// Pendulum speed reduction inside the cloud
        static let toxicCloudSwingReduction: CGFloat = 0.5
        
        // ── Kingdom: Paradise Wind ──
        /// Downward wind force per cigarette in Paradiso
        static let paradiseWindPerCigarette: CGFloat = 0.4
        /// Maximum wind force in Paradiso
        static let paradiseMaxWind: CGFloat = 8.0
        
        // ── Kingdom: Purgatorio Cloud Instability ──
        /// Survival time of clouds with cigarettes > 5 in Purgatorio
        static let purgatorioCloudLifetime: TimeInterval = 0.5
        
        // ── Kingdom: Inferno Haze Reduction ──
        /// Reduction of haze overlay in Inferno ("everyone suffers")
        static let infernoHazeReduction: CGFloat = 0.5
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
