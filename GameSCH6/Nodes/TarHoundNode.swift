import SpriteKit

// MARK: - Tar Hound Node
// Blob di catrame pixel art. Massa amorfa nera-viola con pixel
// irregolari che simulano una superficie vischosa che cola.
// Dimensione 36×26 per leggibilità.

class TarHoundNode: SKSpriteNode {

    enum HoundState { case dormant, awakening, hunting }

    private(set) var state: HoundState = .dormant
    private let px: CGFloat = 4.0

    private var eyeLeft:  SKSpriteNode!
    private var eyeRight: SKSpriteNode!
    private var blobContainer: SKNode!
    private var trailEmitter: SKEmitterNode!

    private var huntSpeed:    CGFloat      = 0
    private var wobbleTimer:  TimeInterval = 0
    private var blobTimer:    TimeInterval = 0

    // MARK: - Init

    init() {
        super.init(texture: nil, color: .clear,
                   size: CGSize(width: 36, height: 26))
        buildPixelBlob()
        setupPhysics()
        enterDormant()
        name = "tarHound"
        zPosition = 38
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    // MARK: - Build

    private func buildPixelBlob() {
        blobContainer = SKNode()
        addChild(blobContainer)

        let coreColor  = SKColor(red: 0.06, green: 0.03, blue: 0.10, alpha: 1)
        let midColor   = SKColor(red: 0.12, green: 0.06, blue: 0.18, alpha: 1)
        let edgeColor  = SKColor(red: 0.20, green: 0.10, blue: 0.28, alpha: 0.8)
        let shineColor = SKColor(red: 0.30, green: 0.15, blue: 0.40, alpha: 0.6)

        // ── Blob principale (griglia irregolare 9×6) ──
        // Forma asimmetrica per sembrare vivo e viscoso
        let blobGrid = [
            "...MMM...",
            "..MCCM...",
            ".MCCCMM..",
            "MMCCCMMM.",
            ".MMMMMM..",
            "..EMEM..."   // Gocce che colano in basso
        ]
        drawGrid(blobGrid, map: [
            "C": coreColor,
            "M": midColor,
            "E": edgeColor
        ], into: blobContainer, ox: 0, oy: 2)

        // ── Pixel di "catrame che cola" ai bordi ──
        let dripsLeft:  [(CGFloat, CGFloat)] = [(-14, 2),(-12,-2),(-16,-1)]
        let dripsRight: [(CGFloat, CGFloat)] = [( 14, 2),( 12,-2),( 16,-1)]
        for (x, y) in dripsLeft + dripsRight {
            let d = SKSpriteNode(color: edgeColor,
                                 size: CGSize(width: px * 0.8, height: px * 0.8))
            d.position = CGPoint(x: x, y: y)
            blobContainer.addChild(d)
        }

        // ── Shine (riflesso viscoso in alto a sinistra) ──
        for pt in [CGPoint(x: -4, y: 6), CGPoint(x: -2, y: 8)] {
            let s = SKSpriteNode(color: shineColor,
                                 size: CGSize(width: px * 0.8, height: px * 0.8))
            s.position = pt
            blobContainer.addChild(s)
        }

        // ── Occhi (pixel 2×2 rossi) ──
        eyeLeft  = makeEye(at: CGPoint(x: -5, y: 4))
        eyeRight = makeEye(at: CGPoint(x:  5, y: 4))
        addChild(eyeLeft)
        addChild(eyeRight)

        // ── Trail di catrame ──
        trailEmitter = SKEmitterNode()
        trailEmitter.particleBirthRate      = 0
        trailEmitter.particleLifetime       = 0.9
        trailEmitter.particleLifetimeRange  = 0.2
        trailEmitter.particleSpeed          = 10
        trailEmitter.particleSpeedRange     = 4
        trailEmitter.emissionAngle          = .pi
        trailEmitter.emissionAngleRange     = 0.7
        trailEmitter.particleAlpha          = 0.6
        trailEmitter.particleAlphaSpeed     = -0.65
        trailEmitter.particleScale          = 0.09
        trailEmitter.particleScaleSpeed     = 0.02
        trailEmitter.particleColor          = SKColor(red: 0.08, green: 0.04, blue: 0.12, alpha: 1)
        trailEmitter.particleColorBlendFactor = 1.0
        trailEmitter.position  = CGPoint(x: -14, y: 0)
        trailEmitter.zPosition = -1
        addChild(trailEmitter)

        // ── Animazione: pulsazione blob (respira) ──
        let breathe = SKAction.sequence([
            SKAction.scaleX(to: 1.06, duration: 0.6),
            SKAction.scaleX(to: 0.94, duration: 0.6)
        ])
        blobContainer.run(SKAction.repeatForever(breathe))
    }

    private func makeEye(at pt: CGPoint) -> SKSpriteNode {
        let eye = SKSpriteNode(color: GameConstants.Colors.infernoAccent,
                               size: CGSize(width: px, height: px))
        eye.position = pt
        eye.zPosition = 2
        eye.alpha = 0  // Nascosto finché dormiente
        return eye
    }

    // MARK: - Physics

    private func setupPhysics() {
        let body = SKPhysicsBody(circleOfRadius: 14)
        body.isDynamic         = true
        body.affectedByGravity = false
        body.mass              = 0.3
        body.categoryBitMask    = GameConstants.Physics.enemy
        body.contactTestBitMask = GameConstants.Physics.player
        body.collisionBitMask   = 0
        physicsBody = body
    }

    // MARK: - State machine

    private func enterDormant() {
        state = .dormant
        alpha = 0.18
        physicsBody?.categoryBitMask = 0
        eyeLeft.alpha  = 0
        eyeRight.alpha = 0
        trailEmitter.particleBirthRate = 0

        let drift = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 10, duration: 3.5),
            SKAction.moveBy(x: 0, y: -10, duration: 3.5)
        ])
        run(SKAction.repeatForever(drift), withKey: "dormant_drift")
    }

    func awaken() {
        guard state == .dormant else { return }
        state = .awakening
        removeAction(forKey: "dormant_drift")

        run(SKAction.sequence([
            SKAction.run { [weak self] in
                self?.eyeLeft.run(SKAction.fadeIn(withDuration: 0.25))
                self?.eyeRight.run(SKAction.fadeIn(withDuration: 0.25))
            },
            SKAction.wait(forDuration: 0.3),
            SKAction.fadeAlpha(to: 0.90, duration: 0.5),
            SKAction.run { [weak self] in
                self?.trailEmitter.particleBirthRate = 14
                self?.physicsBody?.categoryBitMask = GameConstants.Physics.enemy
                self?.state = .hunting
                // Pulsazione occhi una volta attivo
                let eyePulse = SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.4, duration: 0.2),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.2)
                ])
                self?.eyeLeft.run(SKAction.repeatForever(eyePulse))
                self?.eyeRight.run(SKAction.repeatForever(eyePulse))
            }
        ]))
    }

    func goBackToDormant() {
        guard state != .dormant else { return }
        run(SKAction.sequence([
            SKAction.run { [weak self] in
                self?.eyeLeft.run(SKAction.fadeOut(withDuration: 0.4))
                self?.eyeRight.run(SKAction.fadeOut(withDuration: 0.4))
                self?.trailEmitter.particleBirthRate = 0
            },
            SKAction.fadeAlpha(to: 0.18, duration: 0.7),
            SKAction.run { [weak self] in self?.enterDormant() }
        ]))
    }

    // MARK: - Update

    func update(deltaTime: TimeInterval, playerPosition: CGPoint,
                smokeIntensity: CGFloat) {
        guard state == .hunting else { return }

        let baseSpeed = GameConstants.SmokeMirror.tarHoundBaseSpeed
        let maxSpeed  = GameConstants.SmokeMirror.tarHoundMaxSpeed
        huntSpeed = baseSpeed + (maxSpeed - baseSpeed) * smokeIntensity

        let dx   = playerPosition.x - position.x
        let dy   = playerPosition.y - position.y
        let dist = hypot(dx, dy)
        guard dist > 5 else { return }

        wobbleTimer += deltaTime
        let wX = sin(wobbleTimer * 3.0) * 14.0
        let wY = cos(wobbleTimer * 2.3) * 9.0
        let spd = huntSpeed * CGFloat(deltaTime)

        position.x += (dx / dist) * spd + CGFloat(wX) * CGFloat(deltaTime)
        position.y += (dy / dist) * spd + CGFloat(wY) * CGFloat(deltaTime)
        xScale = dx > 0 ? 1 : -1

        // Occhi si ingrandiscono avvicinandosi
        let prox  = max(0, 1.0 - dist / 300.0)
        let eSize = 1.0 + prox * 0.6
        eyeLeft.setScale(eSize)
        eyeRight.setScale(eSize)

        // Blob si deforma orizzontalmente in funzione della velocità
        blobTimer += deltaTime
        let deform = 1.0 + sin(blobTimer * 8) * 0.05
        blobContainer.xScale = deform
        blobContainer.yScale = 2.0 - deform
    }

    // MARK: - Utility

    private func drawGrid(_ rows: [String], map: [Character: SKColor],
                          into container: SKNode, ox: CGFloat, oy: CGFloat) {
        let cols = rows.first?.count ?? 0
        let bX   = ox - CGFloat(cols) * px / 2
        let bY   = oy - CGFloat(rows.count) * px / 2
        for (r, row) in rows.enumerated() {
            for (c, ch) in row.enumerated() {
                guard ch != ".", let col = map[ch] else { continue }
                let b = SKSpriteNode(color: col, size: CGSize(width: px, height: px))
                b.position = CGPoint(x: bX + CGFloat(c)*px + px/2,
                                     y: bY + CGFloat(rows.count - r - 1)*px + px/2)
                container.addChild(b)
            }
        }
    }
}
