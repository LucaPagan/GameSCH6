import SpriteKit

// MARK: - Haze Pigeon Node
// Piccione grottesco pixel art, consumato dal fumo.
// Corpo grigio-viola sgraziato, occhi rossi iniettati di sangue,
// ali consunte con buchi, scia di fumo denso.
// Dimensione aumentata a 34×28 per leggibilità.

class HazePigeonNode: SKSpriteNode {

    enum PigeonState {
        case circling
        case diving
        case retreating
    }

    private(set) var state: PigeonState = .circling
    private let divingSpeed: CGFloat  = 300
    private let circleRadius: CGFloat = 150
    private let px: CGFloat = 3.5

    // Nodi animati
    private var wingLeft:  SKNode!
    private var wingRight: SKNode!
    private var smokeTrail: SKEmitterNode!

    // MARK: - Init

    init() {
        super.init(texture: nil, color: .clear,
                   size: CGSize(width: 34, height: 28))
        setupPhysics()
        buildPixelBody()
        name = "hazePigeon"
        zPosition = 45
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    // MARK: - Physics

    private func setupPhysics() {
        let body = SKPhysicsBody(circleOfRadius: 13)
        body.isDynamic        = true
        body.affectedByGravity = false
        body.mass             = 0.5
        body.categoryBitMask    = GameConstants.Physics.pigeon
        body.contactTestBitMask = GameConstants.Physics.player
        body.collisionBitMask   = 0
        physicsBody = body
    }

    // MARK: - Build pixel body

    private func buildPixelBody() {
        let bodyColor  = SKColor(red: 0.38, green: 0.32, blue: 0.42, alpha: 1)  // grigio-viola sporco
        let darkColor  = SKColor(red: 0.20, green: 0.16, blue: 0.26, alpha: 1)
        let lightColor = SKColor(red: 0.55, green: 0.48, blue: 0.58, alpha: 1)
        let smokeGray  = SKColor(red: 0.30, green: 0.28, blue: 0.32, alpha: 1)

        // ── Corpo (torso 6×5) ──
        let bodyGrid = [
            "..LLL...",
            ".LBBBD..",
            "LBBBDDD.",
            ".LBBBD..",
            "..LBD..."
        ]
        drawGrid(bodyGrid, map: ["L": lightColor, "B": bodyColor, "D": darkColor],
                 ox: 2, oy: 0)

        // ── Testa (più piccola, spostata avanti) ──
        let headGrid = [
            ".HH.",
            "HBBH",
            ".HH."
        ]
        drawGrid(headGrid, map: ["H": lightColor, "B": bodyColor],
                 ox: 12, oy: 4)

        // ── Becco storto ──
        let beak1 = pixel(SKColor(red: 0.65, green: 0.55, blue: 0.20, alpha: 1),
                          at: CGPoint(x: 17, y: 3))
        let beak2 = pixel(SKColor(red: 0.50, green: 0.40, blue: 0.14, alpha: 1),
                          at: CGPoint(x: 19, y: 2))
        addChild(beak1); addChild(beak2)

        // ── Occhio destro (iniettato di fumo rosso) ──
        let eyeWhite = pixel(SKColor(red: 0.85, green: 0.75, blue: 0.70, alpha: 1),
                             at: CGPoint(x: 14, y: 6), size: px * 1.2)
        let eyePupil = pixel(SKColor(red: 0.80, green: 0.10, blue: 0.05, alpha: 1),
                             at: CGPoint(x: 14, y: 6), size: px * 0.7)
        addChild(eyeWhite); addChild(eyePupil)

        // Pulsazione occhio
        let eyePulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.5, duration: 0.35),
            SKAction.fadeAlpha(to: 1.0, duration: 0.35)
        ])
        eyePupil.run(SKAction.repeatForever(eyePulse))

        // ── Ali (consunte, con "buchi") ──
        wingLeft  = buildWing(side: -1, body: smokeGray, dark: darkColor)
        wingRight = buildWing(side:  1, body: smokeGray, dark: darkColor)
        wingLeft.position  = CGPoint(x: -4, y: 2)
        wingRight.position = CGPoint(x:  4, y: 2)
        addChild(wingLeft)
        addChild(wingRight)

        // ── Zampe (due stick pixel) ──
        for xOff: CGFloat in [-3, 3] {
            let leg = pixel(darkColor, at: CGPoint(x: xOff, y: -11), size: px * 0.8)
            leg.size = CGSize(width: px * 0.8, height: px * 3)
            addChild(leg)
            // Artiglio
            for dxC: CGFloat in [-1, 1] {
                let c = pixel(darkColor, at: CGPoint(x: xOff + dxC * px, y: -14))
                addChild(c)
            }
        }

        // ── Scia di fumo denso ──
        smokeTrail = SKEmitterNode()
        smokeTrail.particleBirthRate    = 18
        smokeTrail.particleLifetime     = 1.0
        smokeTrail.particleLifetimeRange = 0.3
        smokeTrail.particleSpeed        = 12
        smokeTrail.particleSpeedRange   = 4
        smokeTrail.emissionAngle        = .pi
        smokeTrail.emissionAngleRange   = 0.8
        smokeTrail.particleAlpha        = 0.55
        smokeTrail.particleAlphaSpeed   = -0.5
        smokeTrail.particleScale        = 0.10
        smokeTrail.particleScaleSpeed   = 0.04
        smokeTrail.particleColor        = SKColor(red: 0.22, green: 0.20, blue: 0.25, alpha: 1)
        smokeTrail.particleColorBlendFactor = 1.0
        smokeTrail.position  = CGPoint(x: -14, y: 0)
        smokeTrail.zPosition = -1
        addChild(smokeTrail)

        // ── Animazione sbattere ali ──
        startFlapping()
    }

    private func buildWing(side: CGFloat, body: SKColor, dark: SKColor) -> SKNode {
        let container = SKNode()
        // 5 pixel di ala con buco al centro (pixel mancante = ala consumata)
        let positions: [CGFloat] = [-8, -5, -2, 2, 6]
        for (i, x) in positions.enumerated() {
            guard i != 2 else { continue }   // buco nel mezzo
            let b = SKSpriteNode(color: i == 0 || i == 4 ? dark : body,
                                 size: CGSize(width: px, height: px * 2.5))
            b.position = CGPoint(x: x * side, y: 0)
            container.addChild(b)
        }
        return container
    }

    private func startFlapping() {
        let flapUp   = SKAction.scaleY(to:  1.4, duration: 0.12)
        let flapDown = SKAction.scaleY(to: -1.4, duration: 0.12)
        flapUp.timingMode   = .easeInEaseOut
        flapDown.timingMode = .easeInEaseOut
        wingLeft.run(SKAction.repeatForever(SKAction.sequence([flapUp, flapDown])))
        wingRight.run(SKAction.repeatForever(SKAction.sequence([flapDown, flapUp])))
    }

    // MARK: - AI

    func update(deltaTime: TimeInterval, playerPosition: CGPoint) {
        switch state {
        case .circling:   circleAround(playerPosition: playerPosition, deltaTime: deltaTime)
        case .diving:     diveToward(playerPosition: playerPosition, deltaTime: deltaTime)
        case .retreating: retreat(deltaTime: deltaTime)
        }
    }

    func startDive() {
        state = .diving
        let flash = SKAction.sequence([
            SKAction.colorize(with: GameConstants.Colors.infernoAccent,
                              colorBlendFactor: 0.6, duration: 0.08),
            SKAction.colorize(withColorBlendFactor: 0, duration: 0.08)
        ])
        run(SKAction.repeat(flash, count: 3))
        smokeTrail.particleBirthRate = 35
    }

    private func circleAround(playerPosition: CGPoint, deltaTime: TimeInterval) {
        let time  = CACurrentMediaTime()
        let angle = CGFloat(time) * 1.5
        let target = CGPoint(x: playerPosition.x + cos(angle) * circleRadius,
                             y: playerPosition.y + sin(angle) * circleRadius + 100)
        let dx = target.x - position.x
        let dy = target.y - position.y
        let dist = hypot(dx, dy)
        let speed: CGFloat = 100
        position.x += dx * CGFloat(deltaTime) * speed / max(1, dist)
        position.y += dy * CGFloat(deltaTime) * speed / max(1, dist)
        xScale = dx > 0 ? 1 : -1
    }

    private func diveToward(playerPosition: CGPoint, deltaTime: TimeInterval) {
        let dx = playerPosition.x - position.x
        let dy = playerPosition.y - position.y
        let dist = hypot(dx, dy)
        guard dist > 5 else { state = .retreating; smokeTrail.particleBirthRate = 18; return }
        let speed = divingSpeed * CGFloat(deltaTime)
        position.x += (dx / dist) * speed
        position.y += (dy / dist) * speed
        xScale = dx > 0 ? 1 : -1
    }

    private func retreat(deltaTime: TimeInterval) {
        position.y += 200 * CGFloat(deltaTime)
        if let scene = scene, position.y > scene.size.height + 200 {
            removeFromParent()
        }
    }

    // MARK: - Utility

    @discardableResult
    private func pixel(_ color: SKColor, at pt: CGPoint,
                       size s: CGFloat? = nil) -> SKSpriteNode {
        let sz = s ?? px
        let b  = SKSpriteNode(color: color, size: CGSize(width: sz, height: sz))
        b.position = pt
        return b
    }

    private func drawGrid(_ rows: [String], map: [Character: SKColor],
                          ox: CGFloat, oy: CGFloat) {
        let cols = rows.first?.count ?? 0
        let bX   = ox - CGFloat(cols) * px / 2
        let bY   = oy - CGFloat(rows.count) * px / 2
        for (r, row) in rows.enumerated() {
            for (c, ch) in row.enumerated() {
                guard ch != ".", let col = map[ch] else { continue }
                let b = SKSpriteNode(color: col, size: CGSize(width: px, height: px))
                b.position = CGPoint(x: bX + CGFloat(c) * px + px/2,
                                     y: bY + CGFloat(rows.count - r - 1) * px + px/2)
                addChild(b)
            }
        }
    }
}
