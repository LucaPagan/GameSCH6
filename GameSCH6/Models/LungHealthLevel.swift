//
//  LungHealthLevel.swift
//  GameSCH6
//
//  Created by Luca Pagano on 04/04/26.
//


import SpriteKit
import CoreGraphics

// MARK: - Lung Health System
//
// Centralizes all lung health logic in one place.
// Translates the number of cigarettes into:
//   - Health level (4 stages)
//   - Inconsistent rotation penalty
//   - Visual effects (blur, shortness of breath)
//   - Organic cough
//
// INTEGRATION:
//   1. Create an instance in GameScene
//   2. Call update(deltaTime:) every frame
//   3. Read computed values where needed

// MARK: - Health Levels

enum LungHealthLevel: Int, CaseIterable {
    case healthy    = 0   // 0–4  cigarettes → Green
    case strained   = 1   // 5–9  cigarettes → Yellow
    case bronchitis = 2   // 10–14 cigarettes → Orange
    case critical   = 3   // 15+  cigarettes → Red

    static func from(cigarettes: Int) -> LungHealthLevel {
        switch cigarettes {
        case 0...4:   return .healthy
        case 5...9:   return .strained
        case 10...14: return .bronchitis
        default:      return .critical
        }
    }

    var color: SKColor {
        switch self {
        case .healthy:    return SKColor(red: 0.18, green: 0.80, blue: 0.44, alpha: 1)
        case .strained:   return SKColor(red: 0.95, green: 0.85, blue: 0.10, alpha: 1)
        case .bronchitis: return SKColor(red: 0.95, green: 0.50, blue: 0.10, alpha: 1)
        case .critical:   return SKColor(red: 0.90, green: 0.15, blue: 0.10, alpha: 1)
        }
    }

    var label: String {
        switch self {
        case .healthy:    return "❤️  Healthy Lungs"
        case .strained:   return "💛  Strained"
        case .bronchitis: return "🧡  Bronchitis"
        case .critical:   return "❤️‍🔥 Critical"
        }
    }

    /// Descriptive stamina bonus/malus for the secondary label
    var statusDetail: String {
        switch self {
        case .healthy:    return "Maximum Strength"
        case .strained:   return "Irregular Rotation"
        case .bronchitis: return "Cough · Blurred Vision"
        case .critical:   return "Short of Breath · Impaired Vision"
        }
    }
}

// MARK: - Lung Health System

final class LungHealthSystem {

    // ── Current State ──────────────────────────────────────────
    private(set) var level: LungHealthLevel = .healthy
    private(set) var cigarettes: Int = 0

    // ── Inconsistent Rotation ────────────────────────────────────
    // Modifies the player's angularVelocity organically
    private var swingPhase:     CGFloat = 0   // main sinusoidal phase
    private var pauseTimer:     CGFloat = 0   // pause timer
    private var pauseDuration:  CGFloat = 0   // current pause duration
    private var isPaused:       Bool    = false
    private var burstTimer:     CGFloat = 0   // acceleration timer

    // ── Coughing ───────────────────────────────────────────────────
    private var coughAccumulator: CGFloat = 0

    // ── Shortness of Breath ─────────────────────────────────────────
    private var breathPhase: CGFloat = 0
    private var breathShakeAccumulator: CGFloat = 0

    // ── Blurring ───────────────────────────────────────────────
    private(set) var blurIntensity: CGFloat = 0   // 0.0–1.0
    private var blurPhase: CGFloat = 0

    // ── Callbacks to GameScene ────────────────────────────────
    var onCough:       (() -> Void)?   // GameScene triggers detachment
    var onBreathShake: ((CGFloat) -> Void)?  // rhythmic light camera shake

    // MARK: - Main Update

    func update(cigarettes: Int, deltaTime: CGFloat) {
        self.cigarettes = cigarettes
        self.level = LungHealthLevel.from(cigarettes: cigarettes)

        updateSwingModulation(deltaTime: deltaTime)
        updateCough(deltaTime: deltaTime)
        updateBlur(deltaTime: deltaTime)
        if level == .critical {
            updateBreath(deltaTime: deltaTime)
        }
    }

    // MARK: - Inconsistent Rotation
    //
    // Produces a multiplier for angularVelocity that:
    //   Healthy     → 1.0 constant
    //   Strained    → sways slightly (±15%), rare pauses
    //   Bronchitis  → sways significantly (±35%), frequent pauses, bursts
    //   Critical    → nearly uncontrollable (±55%), long pauses, violent bursts

    private(set) var swingMultiplier: CGFloat = 1.0

    private func updateSwingModulation(deltaTime: CGFloat) {
        guard level != .healthy else {
            swingMultiplier = 1.0
            swingPhase = 0
            pauseTimer = 0
            isPaused = false
            return
        }

        let intensity = swingIntensity()

        // ── Pause handling ──
        if isPaused {
            pauseTimer -= deltaTime
            if pauseTimer <= 0 {
                isPaused = false
                burstTimer = CGFloat.random(in: 0.3...0.8)  // mini-burst after pause
            }
            swingMultiplier = 0.08  // nearly still
            return
        }

        // ── Post-pause mini-burst ──
        if burstTimer > 0 {
            burstTimer -= deltaTime
            swingMultiplier = 1.0 + intensity * 0.6
            return
        }

        // ── Main sinusoidal oscillation ──
        swingPhase += deltaTime * (1.2 + intensity * 0.8)
        let sineWave   = sin(swingPhase)
        let secondHarm = sin(swingPhase * 2.3) * 0.3  // secondary harmonic

        swingMultiplier = 1.0 + (sineWave + secondHarm) * intensity * 0.55
        swingMultiplier = max(0.1, swingMultiplier)

        // ── Random pause decision ──
        let pauseChance = intensity * CGFloat(deltaTime) * 0.4
        if CGFloat.random(in: 0...1) < pauseChance {
            isPaused = true
            pauseTimer = CGFloat.random(in: 0.15...0.5) * (1.0 + intensity)
        }
    }

    private func swingIntensity() -> CGFloat {
        switch level {
        case .healthy:    return 0.0
        case .strained:   return 0.28
        case .bronchitis: return 0.55
        case .critical:   return 0.85
        }
    }

    // MARK: - Organic Cough
    //
    // Not a per-frame probability — accumulates "cough risk"
    // that grows over time and discharges when exceeding the threshold.
    // This produces more natural patterns (coughing in groups, then pausing).

    private func updateCough(deltaTime: CGFloat) {
        guard level.rawValue >= LungHealthLevel.bronchitis.rawValue else {
            coughAccumulator = 0
            return
        }

        let ratePerSecond: CGFloat = level == .critical ? 0.055 : 0.025
        coughAccumulator += deltaTime * ratePerSecond

        // Organic noise: risk fluctuates
        let noise = CGFloat.random(in: 0...deltaTime * 0.015)
        coughAccumulator += noise

        if coughAccumulator >= 1.0 {
            coughAccumulator = 0
            onCough?()
        }
    }

    // MARK: - Visual Blur
    //
    // SpriteKit has no native blur — we simulate it with a pulsing overlay.
    // blurIntensity (0–1) is read by GameScene to update the overlay.

    private func updateBlur(deltaTime: CGFloat) {
        let targetBlur: CGFloat
        switch level {
        case .healthy:    targetBlur = 0.0
        case .strained:   targetBlur = 0.0
        case .bronchitis: targetBlur = 0.18
        case .critical:   targetBlur = 0.38
        }

        // The blur pulses slightly (like eyes struggling to focus)
        blurPhase += deltaTime * (level == .critical ? 1.8 : 1.2)
        let pulse = abs(sin(blurPhase)) * (level == .critical ? 0.12 : 0.06)

        let target = targetBlur + pulse
        // Lerp towards target — changes gradually
        blurIntensity += (target - blurIntensity) * CGFloat(deltaTime) * 3.0
        blurIntensity = max(0, min(1, blurIntensity))
    }

    // MARK: - Shortness of Breath (Critical level only)
    //
    // Slow breathing rhythm that causes a micro-shake of the camera
    // and more intense breath particles.

    private(set) var breathIntensity: CGFloat = 0

    private func updateBreath(deltaTime: CGFloat) {
        breathPhase += deltaTime * 0.9  // ~1 breath every 7 seconds
        breathIntensity = max(0, sin(breathPhase))

        // Camera shake synchronized with breath
        breathShakeAccumulator += deltaTime
        if breathShakeAccumulator > 0.05 {
            breathShakeAccumulator = 0
            if breathIntensity > 0.7 {
                let shakeAmount = breathIntensity * 1.5
                onBreathShake?(shakeAmount)
            }
        }
    }
}
