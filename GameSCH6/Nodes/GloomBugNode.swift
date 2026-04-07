import SpriteKit

// MARK: - Gloom Bug Node
// Scarabeo demoniaco pixel art. Corpo chitinoso scuro con zampe appuntite
// e occhi che pulsano. Leggermente più grande (24×18) per leggibilità.

class GloomBugNode: SKSpriteNode {

    private let px: CGFloat = 3.0

    init() {
        super.init(texture: nil, color: .clear,
                   size: CGSize(width: 24, height: 18))
        setupPhysics()
        buildPixelBody()
        name = "gloomBug"
        zPosition = 40
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    private func setupPhysics() {
        let body = SKPhysicsBody(circleOfRadius: 10)
        body.isDynamic = false
        body.categoryBitMask    = GameConstants.Physics.enemy
        body.contactTestBitMask = GameConstants.Physics.player
        body.collisionBitMask   = 0
        physicsBody = body
    }

    private func buildPixelBody() {
        // ── Corpo principale (carapace chitinoso) ──
        // Griglia 8×5 pixel, centrata
        let bodyGrid = [
            "..####..",
            ".######.",
            "########",
            ".######.",
            "..####.."
        ]
        let bodyColor    = SKColor(red: 0.12, green: 0.18, blue: 0.08, alpha: 1)
        let shellColor   = SKColor(red: 0.18, green: 0.28, blue: 0.10, alpha: 1)
        let highlightCol = SKColor(red: 0.28, green: 0.42, blue: 0.14, alpha: 1)

        drawGrid(bodyGrid, colors: ["#": bodyColor, "H": highlightCol],
                 default: shellColor, offsetX: 0, offsetY: 0)

        // Striscia di highlight sul dorso
        let stripe = SKSpriteNode(color: highlightCol,
                                  size: CGSize(width: px * 4, height: px))
        stripe.position = CGPoint(x: 0, y: px)
        addChild(stripe)

        // ── Zampe (3 per lato, appuntite) ──
        let legColor = SKColor(red: 0.08, green: 0.12, blue: 0.04, alpha: 1)
        let legPositions: [(CGFloat, CGFloat, CGFloat)] = [
            // x, y, angolo
            (-10, 3,  -0.6),
            (-10, 0,  -0.9),
            (-10, -3, -1.2),
            ( 10, 3,   0.6),
            ( 10, 0,   0.9),
            ( 10, -3,  1.2)
        ]
        for (x, y, angle) in legPositions {
            let leg = SKSpriteNode(color: legColor,
                                   size: CGSize(width: px * 3, height: px * 0.8))
            leg.position = CGPoint(x: x, y: y)
            leg.zRotation = angle
            addChild(leg)

            // Punta artiglio
            let claw = SKSpriteNode(color: SKColor(red: 0.5, green: 0.6, blue: 0.2, alpha: 1),
                                    size: CGSize(width: px * 0.8, height: px * 0.8))
            claw.position = CGPoint(x: x + cos(angle) * px * 3.5,
                                    y: y + sin(angle) * px * 3.5)
            addChild(claw)
        }

        // ── Occhi demoniaci ──
        for xOff: CGFloat in [-3, 3] {
            let eye = SKSpriteNode(color: SKColor(red: 0.2, green: 0.9, blue: 0.1, alpha: 1),
                                   size: CGSize(width: px, height: px))
            eye.position = CGPoint(x: xOff, y: 2)
            eye.zPosition = 2
            addChild(eye)

            // Pupilla scura
            let pupil = SKSpriteNode(color: .black,
                                     size: CGSize(width: px * 0.5, height: px * 0.5))
            pupil.position = CGPoint(x: xOff, y: 2)
            pupil.zPosition = 3
            addChild(pupil)

            // Pulsazione
            let pulse = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.4, duration: 0.4),
                SKAction.fadeAlpha(to: 1.0, duration: 0.4)
            ])
            eye.run(SKAction.repeatForever(pulse))
        }

        // ── Mandibole ──
        let mandibleColor = SKColor(red: 0.35, green: 0.50, blue: 0.12, alpha: 1)
        for xOff: CGFloat in [-2, 2] {
            let m = SKSpriteNode(color: mandibleColor,
                                 size: CGSize(width: px * 0.8, height: px * 1.5))
            m.position = CGPoint(x: xOff, y: -6)
            m.zPosition = 1
            addChild(m)
        }

        // ── Animazione: tremito passivo ──
        let wiggle = SKAction.sequence([
            SKAction.rotate(byAngle:  0.08, duration: 0.25),
            SKAction.rotate(byAngle: -0.16, duration: 0.50),
            SKAction.rotate(byAngle:  0.08, duration: 0.25)
        ])
        run(SKAction.repeatForever(wiggle))

        // ── Animazione zampe ──
        for child in children where child != self {
            let legWiggle = SKAction.sequence([
                SKAction.scaleX(to: 1.1, duration: 0.3),
                SKAction.scaleX(to: 0.9, duration: 0.3)
            ])
            child.run(SKAction.repeatForever(legWiggle))
        }
    }

    // MARK: - Utility

    private func drawGrid(_ rows: [String],
                          colors: [Character: SKColor],
                          default defaultColor: SKColor,
                          offsetX: CGFloat, offsetY: CGFloat) {
        let cols   = rows.first?.count ?? 0
        let oX     = offsetX - CGFloat(cols) * px / 2
        let oY     = offsetY - CGFloat(rows.count) * px / 2

        for (r, row) in rows.enumerated() {
            for (c, ch) in row.enumerated() {
                guard ch != "." else { continue }
                let col = colors[ch] ?? defaultColor
                let b   = SKSpriteNode(color: col,
                                       size: CGSize(width: px, height: px))
                b.position = CGPoint(x: oX + CGFloat(c) * px + px/2,
                                     y: oY + CGFloat(rows.count - r - 1) * px + px/2)
                addChild(b)
            }
        }
    }
}
