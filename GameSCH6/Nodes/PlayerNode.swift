import SpriteKit

// MARK: - Player Node
//
// PERCHÉ isDynamic NON VIENE MAI CAMBIATO:
//   SpriteKit, quando si riattiva un body con isDynamic = true dopo che era false,
//   resetta internamente la velocity a zero prima che la nostra assegnazione abbia effetto.
//   Questo causava il "cade dritto giù" — la velocity tangenziale calcolata in releaseHold()
//   veniva cancellata dallo stesso framework nello stesso frame.
//
// SOLUZIONE:
//   - isDynamic = true SEMPRE (impostato una volta sola in setupPhysics, mai cambiato)
//   - Agganciato: affectedByGravity = false + velocity azzerata in didSimulatePhysics (GameScene)
//                 position calcolata manualmente da updateRotation() ogni frame
//   - In volo:    affectedByGravity = true + velocity tangenziale → traiettoria balistica

class PlayerNode: SKSpriteNode {

    // MARK: - Stato rotazione

    private(set) var currentHold: HoldNode?
    private(set) var currentAngle: CGFloat = 0
    private(set) var angularVelocity: CGFloat = GameConstants.Swing.baseAngularVelocity
    let armLength: CGFloat = GameConstants.Swing.armLength

    // MARK: - Fumo
    private var smokePerturbation: CGFloat = 0
    private var smokeNoiseTimer: TimeInterval = 0

    // MARK: - Visuals
    private var armLine: SKShapeNode!
    private var orbitCircle: SKShapeNode!
    private var coughEmitter: SKEmitterNode?

    // MARK: - Init

    init() {
        let size = CGSize(width: 26, height: 40)
        super.init(texture: nil, color: GameConstants.Colors.paradisoGold, size: size)
        setupPhysics()
        setupVisuals()
        zPosition = 50
        name = "player"
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    // MARK: - Physics

    private func setupPhysics() {
        let body = SKPhysicsBody(circleOfRadius: 14)
        body.mass = GameConstants.World.playerMass
        body.friction = 0.1
        body.restitution = 0.0
        body.linearDamping = 0.3
        body.allowsRotation = false
        body.isDynamic = true          // SEMPRE true — non modificato mai altrove
        body.affectedByGravity = false // Inizia senza gravità (verrà agganciato subito)

        body.categoryBitMask    = GameConstants.Physics.player
        body.contactTestBitMask = GameConstants.Physics.checkpoint
                                | GameConstants.Physics.enemy
                                | GameConstants.Physics.spike
                                | GameConstants.Physics.pigeon
        body.collisionBitMask   = GameConstants.Physics.boundary

        physicsBody = body
    }

    private func setupVisuals() {
        armLine = SKShapeNode()
        armLine.strokeColor = SKColor.white.withAlphaComponent(0.35)
        armLine.lineWidth = 2
        armLine.lineCap = .round
        armLine.zPosition = 45
        armLine.isHidden = true

        orbitCircle = SKShapeNode(circleOfRadius: armLength)
        orbitCircle.strokeColor = SKColor.white.withAlphaComponent(0.08)
        orbitCircle.lineWidth = 1
        orbitCircle.fillColor = .clear
        orbitCircle.zPosition = 44
        orbitCircle.isHidden = true
    }

    // MARK: - Grab

    func grab(hold: HoldNode, preserveVelocity: Bool = false) {
        guard hold !== currentHold else { return }

        let prevHold = currentHold
        currentHold = hold

        let holdPosInParent = hold.parent?.convert(hold.position, to: parent!) ?? hold.position

        let dx = position.x - holdPosInParent.x
        let dy = position.y - holdPosInParent.y
        currentAngle = atan2(dy, dx)

        // Snap alla distanza esatta del braccio
        position = CGPoint(
            x: holdPosInParent.x + cos(currentAngle) * armLength,
            y: holdPosInParent.y + sin(currentAngle) * armLength
        )

        // Imposta ω
        if !preserveVelocity || prevHold == nil {
            angularVelocity = GameConstants.Swing.baseAngularVelocity
        }

        if let prev = prevHold {
            let prevPos = prev.parent?.convert(prev.position, to: parent!) ?? prev.position
            let toNew = CGPoint(x: holdPosInParent.x - prevPos.x,
                                y: holdPosInParent.y - prevPos.y)
            let cross = toNew.x * sin(currentAngle) - toNew.y * cos(currentAngle)
            angularVelocity = cross < 0 ? -abs(angularVelocity) : abs(angularVelocity)
        }

        // Agganciato: disattiva gravità, azzera velocity, ferma eventuali riattivazioni
        // isDynamic rimane TRUE — fondamentale per il lancio corretto
        removeAction(forKey: "restore_gravity")
        physicsBody?.affectedByGravity = false
        physicsBody?.velocity = .zero
        zRotation = currentAngle + .pi / 2 // Mantieni orientamento dritto all'inizio
        
        // Le linee guida della liana sono rimosse dal visual per aderire alla roccia
        // armLine.isHidden     = false
        // orbitCircle.isHidden = false

        run(SKAction.sequence([
            SKAction.scale(to: 1.15, duration: 0.06),
            SKAction.scale(to: 1.00, duration: 0.10)
        ]))
    }

    // MARK: - Release
    //
    // Funziona perché:
    //   1. isDynamic è già true → SpriteKit non resetta nulla quando "riattiva" il body
    //   2. currentHold = nil prima di tutto il resto → didSimulatePhysics non azzera la velocity
    //   3. affectedByGravity = true → la gravità riprende immediatamente
    //   4. velocity = vettore tangenziale → traiettoria balistica corretta

    func releaseHold(stamina: PlayerStamina) -> CGVector {
        guard currentHold != nil else { return .zero }

        // Dash RADIALE: dritto per dritto verso l'esterno dalla pietra
        let nx = cos(currentAngle)
        let ny = sin(currentAngle)
        
        let jumpForce = GameConstants.Jump.baseForce * stamina.jumpForceMultiplier
        let jumpVelocity = CGVector(dx: nx * jumpForce, dy: ny * jumpForce)

        // currentHold = nil PRIMA di tutto il resto
        currentHold = nil

        // Lancio dritto per dritto (Dash Lineare temporaneo)
        physicsBody?.affectedByGravity = false
        physicsBody?.velocity = jumpVelocity

        // Riattiva la gravità dopo 0.5 secondi di volo dritto
        let restoreGravity = SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.run { [weak self] in
                self?.physicsBody?.affectedByGravity = true
            }
        ])
        run(restoreGravity, withKey: "restore_gravity")

        // Modalità Superman: orienta mani e testa nella direzione di lancio (verso l'esterno)
        zRotation = currentAngle - .pi / 2

        return jumpVelocity
    }

    // MARK: - Update (chiamato ogni frame da GameScene quando agganciato)

    func updateRotation(deltaTime: TimeInterval, stamina: PlayerStamina,
                        holdPositionInParent: CGPoint) {
        guard currentHold != nil else { return }

        smokeNoiseTimer += deltaTime
        if smokeNoiseTimer > GameConstants.Swing.smokeNoisePeriod {
            smokeNoiseTimer = 0
            if stamina.cigarettesLoggedToday > 0 {
                let maxPert = CGFloat(stamina.cigarettesLoggedToday) * GameConstants.Swing.smokePerturbationPerCig
                smokePerturbation = CGFloat.random(in: -maxPert...maxPert)
            } else {
                smokePerturbation = 0
            }
        }

        let omega = angularVelocity + smokePerturbation
        currentAngle += CGFloat(deltaTime) * omega

        position = CGPoint(
            x: holdPositionInParent.x + cos(currentAngle) * armLength,
            y: holdPositionInParent.y + sin(currentAngle) * armLength
        )

        zRotation = currentAngle + .pi / 2
        // Le linee guida della liana sono nascoste, quindi le disabilitiamo
        // updateArmLine(holdPos: holdPositionInParent)
        // orbitCircle.position = holdPositionInParent
    }

    private func updateArmLine(holdPos: CGPoint) {
        let path = CGMutablePath()
        path.move(to: holdPos)
        path.addLine(to: position)
        armLine.path = path
    }

    // MARK: - Animations

    func land() {
        let sq = SKAction.group([SKAction.scaleY(to: 0.88, duration: 0.05),
                                  SKAction.scaleX(to: 1.12, duration: 0.05)])
        let rs = SKAction.group([SKAction.scaleY(to: 1.0,  duration: 0.1),
                                  SKAction.scaleX(to: 1.0,  duration: 0.1)])
        run(SKAction.sequence([sq, rs]), withKey: "land")
    }

    func triggerCoughInterrupt() {
        let flashRed = SKAction.sequence([
            SKAction.colorize(with: .red, colorBlendFactor: 1.0, duration: 0.1),
            SKAction.wait(forDuration: 0.3),
            SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.1)
        ])
        
        let shake = SKAction.sequence([
            SKAction.moveBy(x: -4, y: 0, duration: 0.04),
            SKAction.moveBy(x:  8, y: 0, duration: 0.08),
            SKAction.moveBy(x: -4, y: 0, duration: 0.04)
        ])
        run(SKAction.group([flashRed, shake]))
        spawnCoughBurst()
    }

    private func spawnCoughBurst() {
        if coughEmitter == nil {
            let e = SKEmitterNode()
            e.particleBirthRate  = 60; e.particleLifetime    = 0.35
            e.particleSpeed      = 45; e.emissionAngle       = .pi / 2
            e.emissionAngleRange = 1.2; e.particleAlpha      = 0.65
            e.particleAlphaSpeed = -1.8; e.particleScale     = 0.09
            e.particleColor = SKColor(white: 0.7, alpha: 1)
            coughEmitter = e
        }
        guard let burst = coughEmitter?.copy() as? SKEmitterNode else { return }
        burst.position = CGPoint(x: 0, y: 16)
        burst.numParticlesToEmit = 12
        burst.zPosition = 65
        addChild(burst)
        burst.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.removeFromParent()
        ]))
    }

    var armLineNode: SKShapeNode { armLine }
    var orbitCircleNode: SKShapeNode { orbitCircle }
}
