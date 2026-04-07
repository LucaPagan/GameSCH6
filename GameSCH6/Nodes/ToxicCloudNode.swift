import SpriteKit

// MARK: - Toxic Cloud Node
//
// Nebbia organica e soffusa con tre livelli:
//   1. Blob di pixel che si muovono indipendentemente (random walk)
//   2. Emitter di particelle per la sfumatura
//   3. Overlay schermo quando il player è dentro (vignetta + desaturazione)
//
// Per fumatori: rallenta, drena stamina, offusca la vista.
// Per non fumatori: puramente decorativa.
// Presente in tutti e tre i regni con colori diversi.

class ToxicCloudNode: SKNode {

    // MARK: - Proprietà

    let cloudRadius: CGFloat
    var kingdom: Kingdom = .inferno

    private let px: CGFloat = 5.0
    private var blobPixels: [SKSpriteNode] = []
    private var hazeMist:   SKEmitterNode!
    private var blobTimer:  TimeInterval = 0

    // Overlay schermo (aggiunto alla camera da GameScene quando player è dentro)
    private(set) var screenOverlay: SKNode?

    // MARK: - Init

    init(radius: CGFloat = 60) {
        self.cloudRadius = radius
        super.init()
        name      = "toxicCloud"
        zPosition = 15
        buildCloudPixels()
        setupPhysics(radius: radius)
        startOrganic()
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    // MARK: - Build

    private func buildCloudPixels() {
        // ── Layer 1: pixel blob che formano il corpo della nube ──
        // Posizionati casualmente all'interno di cloudRadius,
        // con dimensioni variabili per un aspetto organico
        let pixelCount = 28
        let rng = SeededRandom(seed: Int(cloudRadius * 7))

        for _ in 0..<pixelCount {
            let angle = rng.next(in: 0 ... .pi * 2)
            let dist  = rng.next(in: 0 ... cloudRadius * 0.65)
            let x     = cos(angle) * dist
            let y     = sin(angle) * dist
            let size  = px * rng.next(in: 1.2...3.5)

            let blob = SKSpriteNode(color: .clear,   // colore impostato in configureForKingdom
                                    size: CGSize(width: size, height: size))
            blob.position = CGPoint(x: x, y: y)
            blob.alpha    = rng.next(in: 0.08...0.22)
            blob.zPosition = 0
            addChild(blob)
            blobPixels.append(blob)
        }

        // ── Layer 2: emitter per la sfumatura esterna ──
        hazeMist = SKEmitterNode()
        hazeMist.particleBirthRate      = 8
        hazeMist.particleLifetime       = 3.0
        hazeMist.particleLifetimeRange  = 1.0
        hazeMist.particleSpeed          = 6
        hazeMist.particleSpeedRange     = 3
        hazeMist.emissionAngleRange     = .pi * 2
        hazeMist.particleAlpha          = 0.12
        hazeMist.particleAlphaRange     = 0.04
        hazeMist.particleAlphaSpeed     = -0.04
        hazeMist.particleScale          = 0.18
        hazeMist.particleScaleRange     = 0.08
        hazeMist.particleScaleSpeed     = 0.02
        hazeMist.particlePositionRange  = CGVector(dx: cloudRadius * 0.7,
                                                   dy: cloudRadius * 0.7)
        hazeMist.zPosition = 1
        addChild(hazeMist)
    }

    private func setupPhysics(radius: CGFloat) {
        let body = SKPhysicsBody(circleOfRadius: radius)
        body.isDynamic          = false
        body.categoryBitMask    = GameConstants.Physics.hazardZone
        body.contactTestBitMask = GameConstants.Physics.player
        body.collisionBitMask   = 0
        physicsBody = body
    }

    // MARK: - Configurazione regno

    func configureForKingdom(_ k: Kingdom) {
        kingdom = k

        let (blobCol, mistCol, overlayCol): (SKColor, SKColor, SKColor)
        switch k {
        case .inferno:
            // Fumo di lava: arancione-grigio scuro
            blobCol    = SKColor(red: 0.35, green: 0.18, blue: 0.08, alpha: 1)
            mistCol    = SKColor(red: 0.40, green: 0.22, blue: 0.10, alpha: 1)
            overlayCol = SKColor(red: 0.20, green: 0.08, blue: 0.04, alpha: 1)
        case .purgatorio:
            // Gas sulfureo: giallo-verde tossico
            blobCol    = SKColor(red: 0.38, green: 0.48, blue: 0.12, alpha: 1)
            mistCol    = SKColor(red: 0.42, green: 0.52, blue: 0.15, alpha: 1)
            overlayCol = SKColor(red: 0.15, green: 0.22, blue: 0.05, alpha: 1)
        case .paradiso:
            // Nebbia sacra corrotta: bianco-grigio spento
            blobCol    = SKColor(red: 0.32, green: 0.32, blue: 0.36, alpha: 1)
            mistCol    = SKColor(red: 0.38, green: 0.38, blue: 0.42, alpha: 1)
            overlayCol = SKColor(red: 0.12, green: 0.12, blue: 0.16, alpha: 1)
        }

        for blob in blobPixels {
            blob.color = blobCol
        }
        hazeMist.particleColor = mistCol

        // Prepara l'overlay schermo (viene aggiunto/rimosso da GameScene)
        buildScreenOverlay(color: overlayCol)
    }

    private func buildScreenOverlay(color: SKColor) {
        let overlay = SKNode()

        // Vignetta ai bordi (4 strisce semi-opache)
        // GameScene la aggiunge alla camera quando il player entra
        let vigSize: CGFloat = 800
        for (dx, dy, w, h): (CGFloat, CGFloat, CGFloat, CGFloat) in [
            (-vigSize/2,  0, 40, vigSize),   // sinistra
            ( vigSize/2,  0, 40, vigSize),   // destra
            (0,  vigSize/2, vigSize, 40),    // sopra
            (0, -vigSize/2, vigSize, 40)     // sotto
        ] {
            let strip = SKSpriteNode(color: color.withAlphaComponent(0.35),
                                     size: CGSize(width: w, height: h))
            strip.position = CGPoint(x: dx, y: dy)
            overlay.addChild(strip)
        }

        // Centro leggermente opacizzato
        let center = SKSpriteNode(color: color.withAlphaComponent(0.12),
                                  size: CGSize(width: vigSize, height: vigSize))
        overlay.addChild(center)

        overlay.alpha    = 0
        overlay.zPosition = 400
        screenOverlay = overlay
    }

    // MARK: - Animazione organica (update ogni frame)

    private func startOrganic() {
        // Pulsazione globale lenta
        let expand   = SKAction.scale(to: 1.12, duration: 2.8)
        let contract = SKAction.scale(to: 0.90, duration: 2.8)
        expand.timingMode   = .easeInEaseOut
        contract.timingMode = .easeInEaseOut
        run(SKAction.repeatForever(SKAction.sequence([expand, contract])))
    }

    /// Aggiorna il movimento organico dei pixel blob — chiamare ogni frame
    func updateOrganic(deltaTime: TimeInterval) {
        blobTimer += deltaTime
        for (i, blob) in blobPixels.enumerated() {
            let phase  = CGFloat(i) * 0.7
            let driftX = sin(CGFloat(blobTimer) * 0.8 + phase) * 2.5
            let driftY = cos(CGFloat(blobTimer) * 0.6 + phase) * 2.0
            let alphaP = 0.12 + abs(sin(CGFloat(blobTimer) * 0.4 + phase)) * 0.10
            blob.position.x += CGFloat(driftX) * CGFloat(deltaTime)
            blob.position.y += CGFloat(driftY) * CGFloat(deltaTime)
            blob.alpha = alphaP

            // Mantieni i pixel dentro il raggio
            let dist = hypot(blob.position.x, blob.position.y)
            if dist > cloudRadius * 0.7 {
                blob.position.x *= 0.95
                blob.position.y *= 0.95
            }
        }
    }

    // MARK: - Interazione player

    func isPlayerInside(playerPosition: CGPoint) -> Bool {
        let worldPos = parent?.convert(position, to: parent!.parent ?? parent!) ?? position
        return hypot(playerPosition.x - worldPos.x,
                     playerPosition.y - worldPos.y) < cloudRadius * xScale
    }

    func applyEffects(stamina: PlayerStamina, deltaTime: TimeInterval,
                      cameraNode: SKCameraNode?) {
        guard stamina.cigarettesLoggedToday > 0 else { return }

        // Drain stamina
        _ = stamina.consume(amount: GameConstants.SmokeMirror.toxicCloudStaminaDrain
                                    * CGFloat(deltaTime))

        // Mostra overlay schermo
        if let overlay = screenOverlay, overlay.parent == nil,
           let cam = cameraNode {
            cam.addChild(overlay)
            overlay.run(SKAction.fadeAlpha(to: 1, duration: 0.3))
        }

        // Pixel blob più intensi dentro la nube
        hazeMist.particleBirthRate = 20
    }

    func playerExited(cameraNode: SKCameraNode?) {
        hazeMist.particleBirthRate = 8
        if let overlay = screenOverlay {
            overlay.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.5),
                SKAction.removeFromParent()
            ]))
        }
    }
}

// MARK: - SeededRandom (locale, non duplica quella di WorldBackground)

private class SeededRandom {
    private var s: UInt64
    init(seed: Int) {
        s = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        for _ in 0..<10 { _ = next() }
    }
    private func next() -> UInt64 {
        s = s &* 6364136223846793005 &+ 1442695040888963407; return s
    }
    func next(in r: ClosedRange<CGFloat>) -> CGFloat {
        r.lowerBound + (CGFloat(next()) / CGFloat(UInt64.max)) * (r.upperBound - r.lowerBound)
    }
}
