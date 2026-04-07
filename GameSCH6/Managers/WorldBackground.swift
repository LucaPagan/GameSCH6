//
//  WorldBackground.swift
//  GameSCH6
//
//  Created by Luca Pagano on 03/04/26.
//


import SpriteKit

// MARK: - World Background
//
// Sistema a gradiente solido per regno + elementi decorativi statici ai bordi.
// Tutto viene creato UNA VOLTA SOLA in setup(), mai durante il gameplay.
// Zero caricamento dinamico = zero freeze.
//
// STRUTTURA:
//   - 3 sprite di gradiente (uno per regno), ancorati al mondo
//   - Elementi decorativi pixel-art ai bordi, generati proceduralmente
//     con seed fisso (stesso risultato ad ogni run)
//
// AGGIUNGERE A GameScene:
//   private var worldBackground: WorldBackground!
//   // in setupBackground():
//   worldBackground = WorldBackground(screenSize: size)
//   worldNode.addChild(worldBackground)
//   // in updateCamera() — NON serve update() ogni frame, è tutto statico

class WorldBackground: SKNode {

    private let screenSize: CGSize
    private let worldHeight: CGFloat = GameConstants.World.totalWorldHeight
    private let px: CGFloat = 7.0   // dimensione "pixel" elementi decorativi

    // Altitudini assolute dei confini tra regni
    private var infernoEnd:    CGFloat { GameConstants.Kingdoms.infernoEnd    * worldHeight }
    private var purgatorioEnd: CGFloat { GameConstants.Kingdoms.purgatorioEnd * worldHeight }

    // MARK: - Init

    init(screenSize: CGSize) {
        self.screenSize = screenSize
        super.init()
        zPosition = -200
        setup()
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    // MARK: - Setup (chiamato una volta sola)

    private func setup() {
        buildInferno()
        buildPurgatorio()
        buildParadiso()
    }

    // MARK: ── INFERNO (0 → 33% del mondo) ───────────────────────
    //
    // Gradiente: nero-blu notte in basso → rosso scuro in alto
    // Decorazioni: stalattiti di roccia vulcanica, vene di lava ai bordi

    private func buildInferno() {
        let bottom: CGFloat = 0
        let top:    CGFloat = infernoEnd
        let height          = top - bottom

        // ── Gradiente base ──
        // Approssimato con 3 bande per evitare texture offscreen:
        // nero-blu → rosso-notte → rosso scuro
        let bands: [(CGFloat, SKColor, SKColor)] = [
            // (altezza relativa, colore basso, colore alto)
            (0.45, c(0.04,0.04,0.10), c(0.10,0.03,0.03)),  // notte → brace
            (0.35, c(0.10,0.03,0.03), c(0.16,0.04,0.03)),  // brace → rosso
            (0.20, c(0.16,0.04,0.03), c(0.20,0.06,0.04))   // rosso → sommità
        ]
        addGradientBands(bands: bands, totalHeight: height, yOffset: bottom)

        // ── Decorazioni ──
        let rng = SeededRandom(seed: 0)

        // Parete sinistra: roccia vulcanica
        addWall(x: 0, fromLeft: true, maxDepth: px * 8,
                height: height, yOffset: bottom,
                rock: c(0.18,0.07,0.05), lava: GameConstants.Colors.infernoAccent,
                lavaChance: 0.07, rng: SeededRandom(seed: 1))

        // Parete destra
        addWall(x: screenSize.width, fromLeft: false, maxDepth: px * 8,
                height: height, yOffset: bottom,
                rock: c(0.18,0.07,0.05), lava: GameConstants.Colors.infernoAccent,
                lavaChance: 0.07, rng: SeededRandom(seed: 2))

        // Stalattiti sparse (solo nella metà superiore per non coprire l'inizio)
        let stalCount = 28
        for i in 0..<stalCount {
            let x   = rng.next(in: px * 10 ... screenSize.width - px * 10)
            let y   = rng.next(in: height * 0.15 ... height * 0.95) + bottom
            let len = rng.next(in: px * 4 ... px * 12)
            addStalactite(x: x, tipY: y, length: len,
                          rock: c(0.15,0.06,0.04),
                          glow: GameConstants.Colors.infernoAccent,
                          glowChance: 0.25, rng: rng)
        }

        // Braci luminose
        addEmbers(count: 45, yOffset: bottom, height: height,
                  accent: GameConstants.Colors.infernoAccent,
                  ember: c(1.0,0.58,0.12),
                  rng: SeededRandom(seed: 3))
    }

    // MARK: ── PURGATORIO (33% → 66% del mondo) ──────────────────
    //
    // Gradiente: verde oliva scuro → ocra caldo
    // Decorazioni: rocce arrotondate, erba stilizzata ai bordi

    private func buildPurgatorio() {
        let bottom = infernoEnd
        let top    = purgatorioEnd
        let height = top - bottom

        let bands: [(CGFloat, SKColor, SKColor)] = [
            (0.40, c(0.14,0.20,0.10), c(0.22,0.30,0.14)),
            (0.35, c(0.22,0.30,0.14), c(0.34,0.38,0.18)),
            (0.25, c(0.34,0.38,0.18), c(0.42,0.38,0.22))
        ]
        addGradientBands(bands: bands, totalHeight: height, yOffset: bottom)

        // Pareti rocciose più arrotondate (profondità minore)
        addWall(x: 0, fromLeft: true, maxDepth: px * 6,
                height: height, yOffset: bottom,
                rock: c(0.28,0.34,0.18), lava: GameConstants.Colors.purgatorioWarm,
                lavaChance: 0.04, rng: SeededRandom(seed: 4))

        addWall(x: screenSize.width, fromLeft: false, maxDepth: px * 6,
                height: height, yOffset: bottom,
                rock: c(0.28,0.34,0.18), lava: GameConstants.Colors.purgatorioWarm,
                lavaChance: 0.04, rng: SeededRandom(seed: 5))

        // Rocce sporgenti ai bordi (blocchi più grandi, irregolari)
        let rng = SeededRandom(seed: 6)
        let rockCount = 20
        for i in 0..<rockCount {
            let side    = i % 2 == 0
            let x: CGFloat = side ? 0 : screenSize.width
            let y       = rng.next(in: px * 4 ... height - px * 4) + bottom
            let w       = rng.next(in: px * 3 ... px * 10)
            let h       = rng.next(in: px * 2 ... px * 6)
            addRockBlock(x: side ? 0 : screenSize.width - w,
                         y: y, w: w, h: h,
                         color: c(0.32,0.36,0.20).withAlphaComponent(0.85))
        }

        // Erba stilizzata (piccoli picchi pixel ai bordi bassi del segmento)
        addGrass(yOffset: bottom, height: height * 0.3,
                 color: c(0.25,0.50,0.18), rng: SeededRandom(seed: 7))
    }

    // MARK: ── PARADISO (66% → 100% del mondo) ───────────────────
    //
    // Gradiente: azzurro cielo → bianco-oro luminoso
    // Decorazioni: nuvole pixel stilizzate, raggi di luce ai bordi

    private func buildParadiso() {
        let bottom = purgatorioEnd
        let top    = worldHeight
        let height = top - bottom

        let bands: [(CGFloat, SKColor, SKColor)] = [
            (0.35, GameConstants.Colors.paradisoSky, c(0.65,0.88,0.96)),
            (0.35, c(0.65,0.88,0.96),               c(0.82,0.92,0.98)),
            (0.30, c(0.82,0.92,0.98),               c(0.96,0.96,0.92))
        ]
        addGradientBands(bands: bands, totalHeight: height, yOffset: bottom)

        // Pareti quasi invisibili (cielo aperto — profondità minima)
        addWall(x: 0, fromLeft: true, maxDepth: px * 3,
                height: height, yOffset: bottom,
                rock: c(0.70,0.85,0.92), lava: GameConstants.Colors.paradisoGold,
                lavaChance: 0.05, rng: SeededRandom(seed: 8))

        addWall(x: screenSize.width, fromLeft: false, maxDepth: px * 3,
                height: height, yOffset: bottom,
                rock: c(0.70,0.85,0.92), lava: GameConstants.Colors.paradisoGold,
                lavaChance: 0.05, rng: SeededRandom(seed: 9))

        // Nuvole pixel stilizzate
        let rng = SeededRandom(seed: 10)
        let cloudCount = 35
        for _ in 0..<cloudCount {
            let x = rng.next(in: px * 5 ... screenSize.width - px * 5)
            let y = rng.next(in: 0 ... height) + bottom
            let w = rng.next(in: px * 6 ... px * 18)
            let h = rng.next(in: px * 2 ... px * 5)
            addCloud(x: x, y: y, w: w, h: h,
                     color: SKColor.white.withAlphaComponent(rng.next(in: 0.25...0.55)))
        }

        // Raggi di luce dorata verticali (sottili, semitrasparenti)
        let rayCount = 12
        for i in 0..<rayCount {
            let x   = screenSize.width * CGFloat(i) / CGFloat(rayCount)
                    + rng.next(in: -20...20)
            let rH  = rng.next(in: height * 0.05 ... height * 0.20)
            let rY  = rng.next(in: 0 ... height - rH) + bottom
            addRay(x: x, y: rY, height: rH,
                   color: GameConstants.Colors.paradisoGold.withAlphaComponent(0.08))
        }

        // Particelle di luce (pixel dorati sparsi)
        addEmbers(count: 40, yOffset: bottom, height: height,
                  accent: GameConstants.Colors.paradisoGold,
                  ember: GameConstants.Colors.paradisoGreen,
                  rng: SeededRandom(seed: 11))
    }

    // MARK: ── Primitive ──────────────────────────────────────────

    /// Gradiente approssimato con bande di colore (nessuna texture)
    private func addGradientBands(bands: [(CGFloat, SKColor, SKColor)],
                                  totalHeight: CGFloat, yOffset: CGFloat) {
        // Numero di step molto basso — transizioni ampie e morbide,
        // nessuna banda orizzontale visibile durante il movimento.
        let stepsPerBand = 12
        var currentY = yOffset

        for (fraction, colBottom, colTop) in bands {
            let bandH    = totalHeight * fraction
            let stepH    = bandH / CGFloat(stepsPerBand)

            for i in 0..<stepsPerBand {
                let t   = CGFloat(i) / CGFloat(stepsPerBand)
                let col = lerp(colBottom, colTop, t)
                let b   = SKSpriteNode(color: col,
                                       size: CGSize(width: screenSize.width,
                                                    height: stepH + 1))
                b.anchorPoint = .zero
                b.position    = CGPoint(x: 0, y: currentY + CGFloat(i) * stepH)
                b.zPosition   = -1
                addChild(b)
            }
            currentY += bandH
        }
    }

    /// Parete rocciosa frastagliata con pixel di lava occasionali
    private func addWall(x: CGFloat, fromLeft: Bool, maxDepth: CGFloat,
                         height: CGFloat, yOffset: CGFloat,
                         rock: SKColor, lava: SKColor, lavaChance: CGFloat,
                         rng: SeededRandom) {
        var y: CGFloat = yOffset
        while y < yOffset + height {
            let blockH = px * CGFloat(Int(rng.next(in: 1...3)))
            let depth  = px * CGFloat(Int(rng.next(in: 1...Int(maxDepth / px))))
            let xPos   = fromLeft ? 0 : screenSize.width - depth
            let isLava = rng.next(in: 0...1) < lavaChance
            let col    = isLava
                ? lava.withAlphaComponent(0.9)
                : rock.withAlphaComponent(rng.next(in: 0.55...1.0))
            let b = SKSpriteNode(color: col,
                                 size: CGSize(width: depth, height: blockH + 1))
            b.anchorPoint = .zero
            b.position    = CGPoint(x: xPos, y: y)
            b.zPosition   = 0
            addChild(b)
            y += blockH
        }
    }

    /// Stalattite pixel che pende verso il basso
    private func addStalactite(x: CGFloat, tipY: CGFloat, length: CGFloat,
                               rock: SKColor, glow: SKColor, glowChance: CGFloat,
                               rng: SeededRandom) {
        let steps = Int(length / px)
        guard steps > 0 else { return }
        for i in 0..<steps {
            let t    = CGFloat(i) / CGFloat(steps)
            let w    = px * (1.0 + t * CGFloat(steps / 2))
            let yPos = tipY - CGFloat(i) * px
            let col  = (t < 0.3 && rng.next(in: 0...1) < glowChance) ? glow : rock
            let row  = SKSpriteNode(color: col, size: CGSize(width: w, height: px))
            row.anchorPoint = CGPoint(x: 0.5, y: 0)
            row.position    = CGPoint(x: x, y: yPos)
            row.zPosition   = 0
            addChild(row)
        }
    }

    /// Blocco di roccia rettangolare
    private func addRockBlock(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
                              color: SKColor) {
        let b = SKSpriteNode(color: color, size: CGSize(width: w, height: h))
        b.anchorPoint = .zero
        b.position    = CGPoint(x: x, y: y)
        b.zPosition   = 0
        addChild(b)
    }

    /// Erba pixel stilizzata (piccoli picchi verticali ai bordi)
    private func addGrass(yOffset: CGFloat, height: CGFloat,
                          color: SKColor, rng: SeededRandom) {
        // Bordo sinistro
        var x: CGFloat = 0
        while x < screenSize.width * 0.15 {
            let bladeH = px * rng.next(in: 2...6)
            let bladeW = px
            let y      = rng.next(in: yOffset ... yOffset + height)
            let b      = SKSpriteNode(color: color.withAlphaComponent(0.7),
                                      size: CGSize(width: bladeW, height: bladeH))
            b.anchorPoint = .zero
            b.position    = CGPoint(x: x, y: y)
            b.zPosition   = 0
            addChild(b)
            x += px * rng.next(in: 1...3)
        }
        // Bordo destro (speculare)
        var xR = screenSize.width * 0.85
        while xR < screenSize.width {
            let bladeH = px * rng.next(in: 2...6)
            let y      = rng.next(in: yOffset ... yOffset + height)
            let b      = SKSpriteNode(color: color.withAlphaComponent(0.7),
                                      size: CGSize(width: px, height: bladeH))
            b.anchorPoint = .zero
            b.position    = CGPoint(x: xR, y: y)
            b.zPosition   = 0
            addChild(b)
            xR += px * rng.next(in: 1...3)
        }
    }

    /// Nuvola pixel stilizzata (rettangolo con "righe" sfalsate)
    private func addCloud(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
                          color: SKColor) {
        // Base
        let base = SKSpriteNode(color: color, size: CGSize(width: w, height: h))
        base.anchorPoint = .zero
        base.position    = CGPoint(x: x, y: y)
        base.zPosition   = 0
        addChild(base)

        // Rigonfiamento superiore (più stretta)
        let bump = SKSpriteNode(color: color,
                                size: CGSize(width: w * 0.6, height: h * 0.6))
        bump.anchorPoint = .zero
        bump.position    = CGPoint(x: x + w * 0.2, y: y + h)
        bump.zPosition   = 0
        addChild(bump)
    }

    /// Raggio di luce verticale semitrasparente
    private func addRay(x: CGFloat, y: CGFloat, height: CGFloat, color: SKColor) {
        let b = SKSpriteNode(color: color,
                             size: CGSize(width: px * 2, height: height))
        b.anchorPoint = .zero
        b.position    = CGPoint(x: x, y: y)
        b.zPosition   = 0
        addChild(b)
    }

    /// Pixel luminosi sparsi (braci o particelle di luce)
    private func addEmbers(count: Int, yOffset: CGFloat, height: CGFloat,
                           accent: SKColor, ember: SKColor, rng: SeededRandom) {
        for _ in 0..<count {
            let x   = rng.next(in: px * 12 ... screenSize.width - px * 12)
            let y   = rng.next(in: 0...height) + yOffset
            let col = rng.next(in: 0...1) > 0.5 ? accent : ember
            let s   = px * rng.next(in: 0.4...1.2)
            let b   = SKSpriteNode(color: col.withAlphaComponent(rng.next(in: 0.2...0.6)),
                                   size: CGSize(width: s, height: s))
            b.anchorPoint = .zero
            b.position    = CGPoint(x: x, y: y)
            b.zPosition   = 0
            addChild(b)
        }
    }

    // MARK: ── Utilità ────────────────────────────────────────────

    private func lerp(_ a: SKColor, _ b: SKColor, _ t: CGFloat) -> SKColor {
        var r1: CGFloat=0, g1: CGFloat=0, b1: CGFloat=0, a1: CGFloat=0
        var r2: CGFloat=0, g2: CGFloat=0, b2: CGFloat=0, a2: CGFloat=0
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return SKColor(red: r1+(r2-r1)*t, green: g1+(g2-g1)*t,
                       blue: b1+(b2-b1)*t, alpha: 1)
    }

    private func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> SKColor {
        SKColor(red: r, green: g, blue: b, alpha: 1)
    }
}

// MARK: - SeededRandom

private class SeededRandom {
    private var s: UInt64

    init(seed: Int) {
        s = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        for _ in 0..<10 { _ = _next() }
    }

    private func _next() -> UInt64 {
        s = s &* 6364136223846793005 &+ 1442695040888963407
        return s
    }

    func next(in range: ClosedRange<CGFloat>) -> CGFloat {
        let r = CGFloat(_next()) / CGFloat(UInt64.max)
        return range.lowerBound + r * (range.upperBound - range.lowerBound)
    }

    func next(in range: ClosedRange<Int>) -> CGFloat {
        next(in: CGFloat(range.lowerBound)...CGFloat(range.upperBound))
    }
}
