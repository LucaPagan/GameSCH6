import SpriteKit

// MARK: - Hold Node (Appiglio)
//
// STILE PIXEL ART:
//   Ogni nodo è composto da blocchi quadrati (pixel da 4pt) che formano
//   forme rocciose irregolari. Esistono 3 varianti per ogni regno,
//   selezionate deterministicamente dalla posizione Y del nodo.
//
// CONTRASTO:
//   Inferno   → rocce grigio-beige chiaro su sfondo rosso scuro
//   Purgatorio → rocce grigio-ocra su sfondo verde oliva
//   Paradiso  → rocce grigio-blu scuro su sfondo azzurro chiaro
//
// EFFETTO GRAB:
//   Al momento dell'aggancio, 6 pixel-frammenti esplodono radialmente
//   dalla superficie della roccia e sfumano in 0.25s.
//   Sottile, senza emitter, generato in codice puro.

class HoldNode: SKSpriteNode {

    let platformType: PlatformType
    var kingdom: Kingdom = .inferno

    // Pixel size per la pixel art
    private let px: CGFloat = 4.0

    // Variante visiva (0, 1, 2) — deterministica dalla posizione
    private var rockVariant: Int = 0

    // Riferimento al container dei pixel per l'effetto grab
    private var rockContainer: SKNode!

    // MARK: - Init

    init(type: PlatformType = .solid) {
        self.platformType = type
        let radius: CGFloat = 16.0
        super.init(texture: nil, color: .clear,
                   size: CGSize(width: radius * 2, height: radius * 2))

        setupPhysics(radius: radius)
        name = "hold_\(type)"
        zPosition = 10
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    // MARK: - Costruzione visiva (chiamata dopo che kingdom e position sono impostati)
    //
    // Va chiamata da DeterministicPlatformGenerator dopo aver
    // impostato hold.kingdom e hold.position.
    // Se non viene chiamata, il nodo rimane invisibile (color: .clear).

    func buildVisuals() {
        // Rimuovi visuals precedenti se rebuild
        rockContainer?.removeFromParent()

        // Variante deterministica dalla posizione Y
        let posHash = abs(Int(position.y * 7 + position.x * 13))
        rockVariant = posHash % 3

        rockContainer = SKNode()
        rockContainer.zPosition = 1
        addChild(rockContainer)

        switch platformType {
        case .solid, .sticky:
            buildRock(variant: rockVariant, into: rockContainer)
        case .crumbling:
            buildCrumblingRock(variant: rockVariant, into: rockContainer)
        case .moving:
            buildMovingRock(variant: rockVariant, into: rockContainer)
        case .bouncy:
            buildBouncyRock(into: rockContainer)
        case .cloud:
            buildCloudHold(into: rockContainer)
        case .spike:
            buildSpike(into: rockContainer)
        case .checkpoint:
            buildCheckpoint(into: rockContainer)
        }

        setupBehavior()
    }

    // MARK: - Palette per regno ad alto contrasto

    private struct RockPalette {
        let base:      SKColor  // colore principale roccia
        let shadow:    SKColor  // ombra (pixel scuri)
        let highlight: SKColor  // luce (pixel chiari)
        let outline:   SKColor  // bordo esterno
    }

    private func palette() -> RockPalette {
        switch kingdom {
        case .inferno:
            // Grigio-beige caldo su sfondo rosso scuro → forte contrasto
            return RockPalette(
                base:      SKColor(red: 0.82, green: 0.75, blue: 0.65, alpha: 1),
                shadow:    SKColor(red: 0.55, green: 0.48, blue: 0.40, alpha: 1),
                highlight: SKColor(red: 0.95, green: 0.90, blue: 0.82, alpha: 1),
                outline:   SKColor(red: 0.35, green: 0.28, blue: 0.22, alpha: 1))
        case .purgatorio:
            // Grigio-pietra freddo su sfondo verde oliva → contrasto netto
            return RockPalette(
                base:      SKColor(red: 0.78, green: 0.78, blue: 0.72, alpha: 1),
                shadow:    SKColor(red: 0.50, green: 0.50, blue: 0.45, alpha: 1),
                highlight: SKColor(red: 0.95, green: 0.95, blue: 0.90, alpha: 1),
                outline:   SKColor(red: 0.28, green: 0.28, blue: 0.24, alpha: 1))
        case .paradiso:
            // Grigio-ardesia scuro su sfondo azzurro chiaro → contrasto massimo
            return RockPalette(
                base:      SKColor(red: 0.28, green: 0.32, blue: 0.42, alpha: 1),
                shadow:    SKColor(red: 0.16, green: 0.18, blue: 0.26, alpha: 1),
                highlight: SKColor(red: 0.45, green: 0.52, blue: 0.65, alpha: 1),
                outline:   SKColor(red: 0.10, green: 0.12, blue: 0.18, alpha: 1))
        }
    }

    // MARK: - Builder: Roccia standard (3 varianti)
    //
    // Ogni variante è una sagoma di pixel che forma una roccia irregolare.
    // La sagoma è definita come griglia di caratteri:
    //   '#' = pixel base, 'H' = highlight, 'S' = shadow, '.' = vuoto

    private func buildRock(variant: Int, into c: SKNode) {
        let p = palette()

        // Griglie 8x6 pixel (centrate su 0,0 con offset -16pt,-12pt)
        let grids: [[String]] = [
            // Variante 0 — roccia larga e bassa
            [".##HHH##.",
             "#HHHH####",
             "#H######S",
             "##S#####S",
             ".#SS###S.",
             "..#SSS#.."],

            // Variante 1 — roccia alta e appuntita
            ["..#HH#...",
             ".#HHHH#..",
             "#HH###S#.",
             "#H####SS.",
             "##S###SS.",
             ".#SSSS#.."],

            // Variante 2 — roccia arrotondata
            [".#HHHH#..",
             "#HHHHHSS.",
             "#H#####S.",
             "#######SS",
             ".##SS##S.",
             "..#SSS#.."]
        ]

        drawPixelGrid(grid: grids[variant],
                      base: p.base, highlight: p.highlight,
                      shadow: p.shadow, outline: p.outline,
                      into: c)
    }

    // MARK: - Builder: Roccia sgretolante

    private func buildCrumblingRock(variant: Int, into c: SKNode) {
        // Stessa forma base ma con pixel mancanti (crepe)
        let p = palette()
        let grids: [[String]] = [
            [".#.HH##..",
             "#HH.H###.",
             "#H###.#S.",
             "##S##.#SS",
             ".#SS.##S.",
             "..#S.S#.."],

            ["..#HH....",
             ".#H.HH#..",
             "#HH###S#.",
             "#.####SS.",
             "##S.##SS.",
             ".#SS.S#.."],

            [".#HH.H#..",
             "#H.HHHSS.",
             "#H#.###S.",
             "#.#####SS",
             ".##SS.#S.",
             "..#.SS#.."]
        ]

        drawPixelGrid(grid: grids[variant],
                      base: p.base.withAlphaComponent(0.85),
                      highlight: p.highlight.withAlphaComponent(0.85),
                      shadow: p.shadow, outline: p.outline,
                      into: c)

        // Linea di crepa sovrapposta
        addCrackLine(into: c, palette: p)
    }

    // MARK: - Builder: Roccia mobile (con indicatore frecce)

    private func buildMovingRock(variant: Int, into c: SKNode) {
        buildRock(variant: variant, into: c)

        // Frecce laterali pixel → indicano movimento orizzontale
        let arrowColor: SKColor
        switch kingdom {
        case .inferno:    arrowColor = SKColor(red: 1.0, green: 0.55, blue: 0.1, alpha: 0.9)
        case .purgatorio: arrowColor = GameConstants.Colors.purgatorioWarm
        case .paradiso:   arrowColor = GameConstants.Colors.paradisoGold
        }

        // Freccia sinistra (3 pixel a L)
        for (dx, dy) in [(-3,0),(-2,1),(-2,-1)] {
            addPixel(at: CGPoint(x: CGFloat(dx)*px - 12, y: CGFloat(dy)*px),
                     color: arrowColor, into: c)
        }
        // Freccia destra
        for (dx, dy) in [(3,0),(2,1),(2,-1)] {
            addPixel(at: CGPoint(x: CGFloat(dx)*px + 12, y: CGFloat(dy)*px),
                     color: arrowColor, into: c)
        }
    }

    // MARK: - Builder: Roccia rimbalzante

    private func buildBouncyRock(into c: SKNode) {
        buildRock(variant: rockVariant, into: c)

        // Tre linee orizzontali sotto la roccia (spring pixel)
        let springColor: SKColor
        switch kingdom {
        case .inferno:    springColor = SKColor(red: 1.0, green: 0.55, blue: 0.1, alpha: 0.9)
        case .purgatorio: springColor = GameConstants.Colors.paradisoGreen
        case .paradiso:   springColor = GameConstants.Colors.paradisoGreen
        }

        for i in 0..<3 {
            let width = CGFloat(5 - i) * px
            let y = -14 - CGFloat(i) * px * 1.5
            let bar = SKSpriteNode(color: springColor,
                                   size: CGSize(width: width, height: px * 0.8))
            bar.position = CGPoint(x: 0, y: y)
            c.addChild(bar)
        }
    }

    // MARK: - Builder: Hold nuvola (Purgatorio / Paradiso)

    private func buildCloudHold(into c: SKNode) {
        // Tre rettangoli sfumati sovrapposti = silhouette nuvola pixel
        let cloudColor = SKColor.white
        let rects: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (-8, 0, 16, 8),     // centro
            (-14, -3, 12, 6),   // sinistra
            (2, -3, 12, 6)      // destra
        ]
        for (x, y, w, h) in rects {
            let b = SKSpriteNode(color: cloudColor.withAlphaComponent(0.75),
                                 size: CGSize(width: w, height: h))
            b.position = CGPoint(x: x + w/2 - 8, y: y + h/2 - 4)
            b.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            c.addChild(b)
        }

        // Bordo pixel più scuro
        let outline = SKSpriteNode(color: SKColor(white: 0.6, alpha: 0.5),
                                   size: CGSize(width: 18, height: 2))
        outline.position = CGPoint(x: 0, y: -5)
        c.addChild(outline)
    }

    // MARK: - Builder: Spike

    private func buildSpike(into c: SKNode) {
        let spikeColor: SKColor
        switch kingdom {
        case .inferno:    spikeColor = GameConstants.Colors.infernoAccent
        case .purgatorio: spikeColor = SKColor(red: 0.85, green: 0.30, blue: 0.15, alpha: 1)
        case .paradiso:   spikeColor = SKColor(red: 0.90, green: 0.20, blue: 0.20, alpha: 1)
        }
        let darkColor = SKColor(red: 0.15, green: 0.05, blue: 0.05, alpha: 1)

        // 4 spine pixel (triangoli composti da pixel)
        let spineAngles: [CGFloat] = [0, .pi/2, .pi, .pi * 1.5]
        for angle in spineAngles {
            let length: CGFloat = 5
            for i in 0..<Int(length) {
                let t = CGFloat(i) / length
                let dist = 8 + CGFloat(i) * px
                let x = cos(angle) * dist
                let y = sin(angle) * dist
                let s = px * (1.0 - t * 0.5)
                let col = i == 0 ? darkColor : spikeColor
                addPixel(at: CGPoint(x: x, y: y), size: s, color: col, into: c)
            }
        }

        // Nucleo centrale scuro
        let core = SKSpriteNode(color: darkColor,
                                size: CGSize(width: px*3, height: px*3))
        core.position = .zero
        c.addChild(core)
    }

    // MARK: - Builder: Checkpoint

    private func buildCheckpoint(into c: SKNode) {
        let p = palette()
        buildRock(variant: rockVariant, into: c)

        // Stella a 4 punte sovrapposta — identifica il checkpoint
        let starColor: SKColor
        switch kingdom {
        case .inferno:    starColor = SKColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1)
        case .purgatorio: starColor = SKColor(red: 0.2, green: 0.9, blue: 0.5, alpha: 1)
        case .paradiso:   starColor = SKColor(red: 1.0, green: 0.95, blue: 0.5, alpha: 1)
        }

        // Croce pixel (stella a 4 punte 3x3)
        let starPixels: [(Int, Int)] = [
            (0,2),(0,1),(0,0),(0,-1),(0,-2),
            (1,0),(-1,0),(2,0),(-2,0)
        ]
        for (dx, dy) in starPixels {
            addPixel(at: CGPoint(x: CGFloat(dx)*px, y: CGFloat(dy)*px),
                     size: px, color: starColor, into: c)
        }

        // Outline scuro attorno alla stella
        let _ = p.outline
        let outerPixels: [(Int,Int)] = [
            (1,2),(-1,2),(1,-2),(-1,-2),
            (2,1),(2,-1),(-2,1),(-2,-1)
        ]
        for (dx, dy) in outerPixels {
            addPixel(at: CGPoint(x: CGFloat(dx)*px, y: CGFloat(dy)*px),
                     size: px,
                     color: SKColor(white: 0.1, alpha: 0.6),
                     into: c)
        }
    }

    // MARK: - Primitive pixel

    private func drawPixelGrid(grid: [String],
                               base: SKColor, highlight: SKColor,
                               shadow: SKColor, outline: SKColor,
                               into c: SKNode) {
        let cols = grid.first?.count ?? 0
        let rows = grid.count
        let offsetX = -CGFloat(cols) * px / 2.0
        let offsetY = -CGFloat(rows) * px / 2.0

        for (row, line) in grid.enumerated() {
            for (col, char) in line.enumerated() {
                let color: SKColor?
                switch char {
                case "#": color = base
                case "H": color = highlight
                case "S": color = shadow
                case "O": color = outline
                default:  color = nil
                }
                guard let col_color = color else { continue }
                let x = offsetX + CGFloat(col) * px + px/2
                let y = offsetY + CGFloat(rows - row - 1) * px + px/2
                addPixel(at: CGPoint(x: x, y: y), size: px, color: col_color, into: c)
            }
        }
    }

    @discardableResult
    private func addPixel(at point: CGPoint, size: CGFloat? = nil,
                          color: SKColor, into c: SKNode) -> SKSpriteNode {
        let s = size ?? px
        let b = SKSpriteNode(color: color, size: CGSize(width: s, height: s))
        b.position = point
        c.addChild(b)
        return b
    }

    private func addCrackLine(into c: SKNode, palette p: RockPalette) {
        // Crepa diagonale frastagliata (5 segmenti pixel)
        let crackColor = p.outline.withAlphaComponent(0.7)
        let steps: [(CGFloat, CGFloat)] = [(-4,4),(-2,2),(0,0),(2,-2),(4,-4)]
        for (x, y) in steps {
            addPixel(at: CGPoint(x: x, y: y), size: px * 0.8,
                     color: crackColor, into: c)
        }
    }

    // MARK: - Behavior

    private func setupBehavior() {
        switch platformType {
        case .moving:
            let moveRight = SKAction.moveBy(x: 50, y: 0, duration: 2.0)
            moveRight.timingMode = .easeInEaseOut
            run(SKAction.repeatForever(SKAction.sequence([moveRight, moveRight.reversed()])))
        case .checkpoint:
            // Pulsazione sottile — solo scala, non distrae
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.10, duration: 0.8),
                SKAction.scale(to: 0.92, duration: 0.8)
            ])
            run(SKAction.repeatForever(pulse))
        case .crumbling:
            // Leggero tremolio passivo che avvisa che è instabile
            let wobble = SKAction.sequence([
                SKAction.rotate(byAngle: 0.03, duration: 0.4),
                SKAction.rotate(byAngle: -0.06, duration: 0.8),
                SKAction.rotate(byAngle: 0.03, duration: 0.4)
            ])
            run(SKAction.repeatForever(wobble))
        default:
            break
        }
    }

    // MARK: - Physics

    private func setupPhysics(radius: CGFloat) {
        let physicsRadius = (platformType == .spike) ? radius * 0.8 : radius * 3.0
        let body = SKPhysicsBody(circleOfRadius: physicsRadius)
        body.isDynamic = false
        body.categoryBitMask = (platformType == .spike)      ? GameConstants.Physics.spike :
                               (platformType == .checkpoint) ? GameConstants.Physics.checkpoint :
                               GameConstants.Physics.hold
        body.collisionBitMask  = 0
        body.contactTestBitMask = GameConstants.Physics.player
        physicsBody = body
    }

    // MARK: - Effetto Grab ─────────────────────────────────────────
    //
    // Chiamato da GameScene quando il player si aggrappa a questa roccia.
    // 6 frammenti-pixel esplodono radialmente dalla superficie e sfumano.
    // Sottile e istantaneo — aumenta la percezione del contatto fisico.

    func playGrabEffect() {
        let p = palette()
        let fragmentCount = 6
        let fragmentColor = p.highlight

        for i in 0..<fragmentCount {
            let angle = CGFloat(i) / CGFloat(fragmentCount) * .pi * 2
            let startDist: CGFloat = 14   // Superficie della roccia
            let endDist:   CGFloat = 22   // Quanto si allontanano

            let startX = cos(angle) * startDist
            let startY = sin(angle) * startDist

            let fragment = SKSpriteNode(
                color: fragmentColor,
                size: CGSize(width: px, height: px))
            fragment.position = CGPoint(x: startX, y: startY)
            fragment.zPosition = 20
            addChild(fragment)

            // Movimento radiale + fade
            let moveOut = SKAction.moveBy(
                x: cos(angle) * (endDist - startDist),
                y: sin(angle) * (endDist - startDist),
                duration: 0.22)
            moveOut.timingMode = .easeOut

            let fade = SKAction.fadeOut(withDuration: 0.22)

            fragment.run(SKAction.group([moveOut, fade])) {
                fragment.removeFromParent()
            }
        }

        // Micro-pulse sulla roccia stessa (scala 1→1.08→1 in 0.12s)
        rockContainer?.run(SKAction.sequence([
            SKAction.scale(to: 1.08, duration: 0.06),
            SKAction.scale(to: 1.00, duration: 0.06)
        ]))
    }

    // MARK: - Interaction

    func onPlayerGrab(stamina: PlayerStamina) -> Bool {
        if platformType == .cloud {
            let threshold = kingdom == .purgatorio ? 5 : 10
            if stamina.cigarettesLoggedToday >= threshold {
                run(SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.2, duration: 0.2),
                    SKAction.fadeAlpha(to: 0.6, duration: 0.5)
                ]))
                return false
            }
        }

        if platformType == .crumbling {
            let crumbleTime: TimeInterval = (kingdom == .purgatorio && stamina.cigarettesLoggedToday > 5)
                ? GameConstants.SmokeMirror.purgatorioCloudLifetime : 1.0
            run(SKAction.sequence([
                SKAction.wait(forDuration: crumbleTime),
                SKAction.run { [weak self] in self?.physicsBody?.categoryBitMask = 0 },
                SKAction.fadeOut(withDuration: 0.3),
                SKAction.wait(forDuration: 3.0),
                SKAction.run { [weak self] in self?.physicsBody?.categoryBitMask = GameConstants.Physics.hold },
                SKAction.fadeIn(withDuration: 0.5)
            ]))
        }

        if kingdom == .paradiso && stamina.cigarettesLoggedToday > 0 {
            let gripDuration = max(0.5, 3.0 - Double(stamina.cigarettesLoggedToday) * 0.15)
            run(SKAction.sequence([
                SKAction.wait(forDuration: gripDuration),
                SKAction.run { [weak self] in
                    self?.run(SKAction.sequence([
                        SKAction.moveBy(x: -2, y: 0, duration: 0.04),
                        SKAction.moveBy(x:  4, y: 0, duration: 0.08),
                        SKAction.moveBy(x: -2, y: 0, duration: 0.04)
                    ]))
                }
            ]), withKey: "paradiso_slip")
        }

        return true
    }
}
