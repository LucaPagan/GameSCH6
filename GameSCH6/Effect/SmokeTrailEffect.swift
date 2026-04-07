import SpriteKit

// MARK: - SmokeTrailEffect
//
// Scia di fumo procedurale attorno al player.
// Nessun asset richiesto — tutto generato via SKEmitterNode.
//
// USO in PlayerNode (o GameScene):
//   let smokeTrail = SmokeTrailEffect()
//   addChild(smokeTrail)   // aggiunto come figlio del playerNode
//   // ogni frame:
//   smokeTrail.update(cigarettes: stamina.cigarettesLoggedToday,
//                     velocity: playerNode.physicsBody?.velocity ?? .zero)

final class SmokeTrailEffect: SKNode {

    // MARK: - Emitters
    private let mainEmitter:   SKEmitterNode  // fumo grigio principale
    private let ashEmitter:    SKEmitterNode  // cenere/scintille
    private let hazeEmitter:   SKEmitterNode  // alone ambientale largo

    // MARK: - State
    private var currentCigarettes: Int = 0

    // MARK: - Init

    override init() {
        mainEmitter  = SmokeTrailEffect.makeMainSmokeEmitter()
        ashEmitter   = SmokeTrailEffect.makeAshEmitter()
        hazeEmitter  = SmokeTrailEffect.makeHazeEmitter()
        super.init()

        zPosition = -1   // dietro il player sprite

        addChild(hazeEmitter)
        addChild(mainEmitter)
        addChild(ashEmitter)

        // Parte disabilitato
        setEmission(rate: 0)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) not supported") }

    // MARK: - Public API

    /// Chiamato ogni frame dal GameScene.update o da PlayerNode.update
    func update(cigarettes: Int, velocity: CGVector) {
        guard cigarettes != currentCigarettes else {
            updateDirection(velocity: velocity)
            return
        }
        currentCigarettes = cigarettes
        applyIntensity(cigarettes: cigarettes)
        updateDirection(velocity: velocity)
    }

    // MARK: - Intensity Mapping

    private func applyIntensity(cigarettes: Int) {
        // 0 sigarette → nessuna scia
        // 1-4          → filo sottile
        // 5-9          → scia media
        // 10-14        → scia densa con cenere
        // 15+          → nube densa + alone + molta cenere

        let t = min(1.0, CGFloat(cigarettes) / 15.0)   // 0.0 → 1.0

        // ── Main smoke ──
        let mainRate   = lerp(0, 28, t)
        let mainSpeed  = lerp(8, 22, t)
        let mainAlpha  = lerp(0.0, 0.55, t)
        let mainScale  = lerp(0.04, 0.22, t)
        let mainLife   = lerp(0.4, 1.6, t)

        mainEmitter.particleBirthRate      = mainRate
        mainEmitter.particleSpeed          = mainSpeed
        mainEmitter.particleAlpha          = mainAlpha
        mainEmitter.particleAlphaRange     = mainAlpha * 0.4
        mainEmitter.particleScale          = mainScale
        mainEmitter.particleScaleRange     = mainScale * 0.6
        mainEmitter.particleLifetime       = mainLife
        mainEmitter.particleLifetimeRange  = mainLife * 0.5

        // ── Ash / sparks (visibili solo da 8+ sigarette) ──
        let ashVisible = cigarettes >= 8
        let ashRate    = ashVisible ? lerp(0, 12, (t - 0.5) / 0.5) : 0
        ashEmitter.particleBirthRate   = max(0, ashRate)
        ashEmitter.particleAlpha       = ashVisible ? lerp(0.0, 0.7, t) : 0

        // ── Haze ambient (visibile da 12+ sigarette) ──
        let hazeVisible = cigarettes >= 12
        let hazeRate    = hazeVisible ? lerp(0, 6, (t - 0.75) / 0.25) : 0
        hazeEmitter.particleBirthRate  = max(0, hazeRate)
        hazeEmitter.particleAlpha      = hazeVisible ? lerp(0.0, 0.18, t) : 0
    }

    private func setEmission(rate: CGFloat) {
        mainEmitter.particleBirthRate  = rate
        ashEmitter.particleBirthRate   = 0
        hazeEmitter.particleBirthRate  = 0
    }

    /// Orienta la scia nella direzione opposta al movimento (effetto realistico)
    private func updateDirection(velocity: CGVector) {
        let speed = hypot(velocity.dx, velocity.dy)
        guard speed > 10 else { return }

        // Angolo opposto al movimento
        let angle = atan2(-velocity.dy, -velocity.dx)

        // Spread in base alla velocità: lento → largo, veloce → stretto
        let spread = CGFloat.pi * lerp(0.9, 0.35, min(1, speed / 300))

        mainEmitter.emissionAngle      = angle
        mainEmitter.emissionAngleRange = spread
        ashEmitter.emissionAngle       = angle
        ashEmitter.emissionAngleRange  = spread * 1.3
        hazeEmitter.emissionAngle      = angle
        hazeEmitter.emissionAngleRange = CGFloat.pi * 2  // sempre omnidirezionale
    }

    // MARK: - Emitter Factories (procedurali, zero assets)

    private static func makeMainSmokeEmitter() -> SKEmitterNode {
        let e = SKEmitterNode()

        // Texture: cerchio sfumato generato proceduralmente
        e.particleTexture = makeCircleTexture(radius: 48)

        e.particleBirthRate     = 0
        e.particleLifetime      = 1.0
        e.particleLifetimeRange = 0.5
        e.particleSpeed         = 12
        e.particleSpeedRange    = 8

        // Colore: grigio-blueish fumo
        e.particleColor            = SKColor(red: 0.62, green: 0.60, blue: 0.65, alpha: 1)
        e.particleColorAlphaRange  = 0.2
        e.particleColorBlueRange   = 0.1

        e.particleAlpha       = 0.4
        e.particleAlphaRange  = 0.15
        e.particleAlphaSpeed  = -0.25   // fade out

        e.particleScale       = 0.10
        e.particleScaleRange  = 0.06
        e.particleScaleSpeed  = 0.08    // si allarga mentre svanisce

        // Lieve deriva verso l'alto (fumo sale)
        e.yAcceleration = 8

        e.emissionAngle      = .pi / 2
        e.emissionAngleRange = .pi

        e.particleBlendMode = .alpha
        return e
    }

    private static func makeAshEmitter() -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = makeSquareTexture(side: 4)

        e.particleBirthRate     = 0
        e.particleLifetime      = 1.2
        e.particleLifetimeRange = 0.6
        e.particleSpeed         = 30
        e.particleSpeedRange    = 20

        // Colore cenere: bianco-grigio con sfumatura giallastra
        e.particleColor           = SKColor(red: 0.85, green: 0.82, blue: 0.75, alpha: 1)
        e.particleColorBlueRange  = 0.15
        e.particleColorRedRange   = 0.1

        e.particleAlpha      = 0.65
        e.particleAlphaSpeed = -0.5

        e.particleScale      = 1.0
        e.particleScaleRange = 0.5

        // Le particelle di cenere cadono leggermente
        e.yAcceleration = -15
        e.xAcceleration = CGFloat.random(in: -5...5)

        // Rotazione della cenere
        e.particleRotation      = 0
        e.particleRotationRange = .pi * 2
        e.particleRotationSpeed = CGFloat.random(in: -3...3)

        e.emissionAngle      = .pi
        e.emissionAngleRange = .pi * 0.8

        e.particleBlendMode = .alpha
        return e
    }

    private static func makeHazeEmitter() -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = makeCircleTexture(radius: 80)

        e.particleBirthRate     = 0
        e.particleLifetime      = 2.5
        e.particleLifetimeRange = 1.0
        e.particleSpeed         = 5
        e.particleSpeedRange    = 3

        // Alone bluastro/violaceo
        e.particleColor           = SKColor(red: 0.30, green: 0.25, blue: 0.45, alpha: 1)
        e.particleColorBlueRange  = 0.2

        e.particleAlpha      = 0.12
        e.particleAlphaRange = 0.06
        e.particleAlphaSpeed = -0.04

        e.particleScale      = 0.6
        e.particleScaleRange = 0.3
        e.particleScaleSpeed = 0.06

        e.yAcceleration = 4

        e.emissionAngle      = .pi / 2
        e.emissionAngleRange = .pi * 2  // omnidirezionale

        e.particleBlendMode = .alpha
        return e
    }

    // MARK: - Procedural Textures

    /// Cerchio sfumato (gaussian-ish) — usato per fumo e alone
    private static func makeCircleTexture(radius: CGFloat) -> SKTexture {
        let size = CGSize(width: radius * 2, height: radius * 2)
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            let center = CGPoint(x: radius, y: radius)
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor.white.cgColor,
                    UIColor.white.withAlphaComponent(0).cgColor
                ] as CFArray,
                locations: [0, 1])!
            ctx.cgContext.drawRadialGradient(
                gradient,
                startCenter: center, startRadius: 0,
                endCenter:   center, endRadius:   radius,
                options: [])
        }
        return SKTexture(image: img)
    }

    /// Quadratino per le particelle di cenere
    private static func makeSquareTexture(side: CGFloat) -> SKTexture {
        let size = CGSize(width: side, height: side)
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        return SKTexture(image: img)
    }
}

// MARK: - Helpers

private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
    return a + (b - a) * max(0, min(1, t))
}


// MARK: - Integration in PlayerNode
//
// Nel tuo PlayerNode.swift aggiungi:
//
//   private let smokeTrail = SmokeTrailEffect()
//
//   // in setupNode() o init():
//   addChild(smokeTrail)
//
//   // in un metodo chiamato ogni frame (o in GameScene.update):
//   func updateSmokeTrail(cigarettes: Int) {
//       let vel = physicsBody?.velocity ?? .zero
//       smokeTrail.update(cigarettes: cigarettes, velocity: vel)
//   }
//
// In GameScene.update() aggiungi la chiamata:
//   playerNode.updateSmokeTrail(cigarettes: stamina.cigarettesLoggedToday)
//
// Già hai updateSmokeMirrorVisuals(cigarettes:) — puoi integrare lì dentro:
//   func updateSmokeMirrorVisuals(cigarettes: Int) {
//       // ... codice esistente ...
//       smokeTrail.update(cigarettes: cigarettes,
//                         velocity: physicsBody?.velocity ?? .zero)
//   }
